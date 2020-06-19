import cv2
import os
import logging
import time
import json
import datetime
import numpy as np
from azure.storage.blob import BlobServiceClient
import requests
import threading
from queue import Queue, Full

from messaging.iotmessenger import IoTInferenceMessenger

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

camera_config = None
intervals_per_cam = dict()
keep_listeing_for_frames = False

frame_queue = Queue(30)

def parse_twin(data):
    global camera_config

    logging.info(f"Retrieved updated properties: {data}")

    if "desired" in data:
      data = data["desired"]

    if "cameras" in data:
      cams = data["cameras"]
    blob = None

    # if blob is not specified we will message
    # the images to the IoT hub
    if "blob" in data:
      blob = data["blob"]

    camera_config = dict()
    camera_config["cameras"] = cams
    camera_config["blob"] = blob

    logging.info(f"config set: {camera_config}")

def module_twin_callback(client):

  while True:
    payload = client.receive_twin_desired_properties_patch()
    parse_twin(payload)

def main():
    global camera_config, keep_listeing_for_frames

    if local:
      # if we are not local this will be overridden anyway
      fn = os.path.join(os.path.dirname(__file__), "desired.json")

      with open(fn, "r") as f:
          camera_config = json.load(f)

    messenger = None
    if not local:
      messenger = IoTInferenceMessenger()
      client = messenger.client

      twin_update_listener = threading.Thread(target=module_twin_callback, args=(client,))
      twin_update_listener.daemon = True
      twin_update_listener.start()

    blob_service_client = None
    frame_grab_listener = None

    # Should be properly asynchronous, but since we don't change things often
    # Wait for it to come back from twin update the very first time
    for i in range(20):
      if camera_config is not None:
        break
      time.sleep(1)

    if camera_config is None:
      payload = client.get_twin()
      parse_twin(payload)

    logging.info("Created camera configuration from twin")

    if camera_config["blob"] is not None:
      blob_service_client = BlobServiceClient.from_connection_string(camera_config["blob"])
      logging.info(f"Created blob service client: {blob_service_client.account_name}")

    while True:
       
      for key, cam in camera_config["cameras"].items():

        if not cam["enabled"]:
            continue
        
        if key not in intervals_per_cam:
          intervals_per_cam[key] = dict()
          
        curtime = time.time()

        # not enough time has passed since the last collection
        if 'interval' in intervals_per_cam[key] and curtime - intervals_per_cam[key]['interval'] < float(cam['interval']):
            continue

        if local:
            vid_file = os.path.join(os.path.dirname(__file__), cam["rtsp"])
        else:
            vid_file = cam["rtsp"]

        # start queuing up images on a different thread
        if 'rtsp' not in intervals_per_cam[key] or intervals_per_cam[key]['rtsp'] != cam['rtsp']:
          intervals_per_cam[key]['rtsp'] = cam['rtsp']

          keep_listeing_for_frames = False
          # stop an existing thread
          if frame_grab_listener is not None:
            frame_grab_listener.join()
            logging.info(f"Stopped listening for {intervals_per_cam[key]['rtsp']}")

          keep_listeing_for_frames = True
          # if we are streaming from a file then pass current expected wait interval. Else - 0
          # the interval will be used to simulate an 30 fps playback
          cur_interval = 0 if cam['rtsp'].startswith("rtsp") else float(cam['interval'])

          frame_grab_listener = threading.Thread(target=grab_image_from_stream, args=(cam['rtsp'], cur_interval))
          frame_grab_listener.daemon = True
          frame_grab_listener.start()
          logging.info(f"Started listening for {cam['rtsp']}")

        # block until we get something
        img = frame_queue.get()
    
        logging.info(f"Grabbed image from {cam['rtsp']}")

        camId = f"{cam['space']}/{key}"

        curtimename = None
        if camera_config["blob"] is not None:
            curtimename, full_cam_id = send_img_to_blob(blob_service_client, img, camId)

        if "inference" in cam and cam["inference"]:
          if "detector" not in cam:
              logging.error(f"Cannot perform inference: detector not specified for camera {key}")
          else:
              infer_and_report(messenger, full_cam_id, cam["detector"], img, curtimename)

        # message the image capture upstream
        if curtimename is not None:
          messenger.send_image(camId, curtimename)
          logging.info(f"Notified of image upload: {cam['rtsp']} to {cam['space']}")

        # update collection time for camera
        intervals_per_cam[key]['interval'] = curtime


def infer_and_report(messenger, cam_id, detector, img, curtimename):
  try:
    classes, scores, boxes, proc_time = infer(detector, img)

    if local:
        return

    report(messenger, cam_id, classes, scores,
            boxes, curtimename, proc_time)

  except Exception as e:
    logging.error(f"Exception occured during inference: {e}")


def infer(detector, img):
  im = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
  im = cv2.resize(im, (300, 300), interpolation=cv2.INTER_LINEAR)

  data = json.dumps({"img": im.tolist()})
  headers = {'Content-Type': "application/json"}
  start = time.time()
  resp = requests.post(detector, data, headers=headers)
  proc_time = time.time() - start
  resp.raise_for_status()
  result = resp.json()

  return result["classes"], result["scores"], result["bboxes"], proc_time


def report(messenger, cam, classes, scores, boxes, curtimename, proc_time):
  messenger.send_upload(cam, len(scores), curtimename, proc_time)
  time.sleep(0.01)
  messenger.send_inference(cam, classes, scores, boxes, curtimename)


def get_image_local_name(curtime):
  return os.path.abspath(curtime.strftime("%Y_%m_%d_%H_%M_%S_%f") + ".jpg")


def send_img_to_blob(blob_service_client, img, camId):

  curtime = datetime.datetime.utcnow()
  name = curtime.isoformat() + "Z"

  # used to write temporary local file
  # because that's how the SDK works.
  # the file name is used upload to blob
  local_name = get_image_local_name(curtime)
  day = curtime.strftime("%Y-%m-%d")

  blob_client = blob_service_client.get_blob_client("still-images", f"{camId}/{day}/{name}.jpg")
  cv2.imwrite(local_name, img)

  with open(local_name, "rb") as data:
    blob_client.upload_blob(data)

  os.remove(local_name)
  return name, f"{camId}/{day}"


def grab_image_from_stream(cam, interval = 0):

  repeat = 3
  wait = 0.5
  frame = None

  video_capture = cv2.VideoCapture(cam)

  fps = None
  delay = None
  fps_set = False

  while keep_listeing_for_frames:
    start = time.time()

    for _ in range(repeat):
      try:
          res, frame = video_capture.read()

          if not res:
            video_capture = cv2.VideoCapture(cam)
            res, frame = video_capture.read()
          break
      except:
          # try to re-capture the stream
          logging.info("Could not capture video. Recapturing and retrying...")
          time.sleep(wait)

    if frame is None:
      logging.info("Failed to capture frame, sending blank image")
      continue

    # retrieve camera properties. 
    # fps may not always be available
    if not fps_set and fps is None:
      fps = video_capture.get(cv2.CAP_PROP_FPS)
      fps_set = True
      
      if fps is not None and fps > 0:
        delay = 1. / fps
        
      logging.info(f"Retrieved FPS: {fps}")

    # we are reading from a file, simulate 30 fps streaming
    # delay appropriately before enqueueing
    if interval > 0:
      cur_delay = delay - (time.time() - start)
      if cur_delay > 0:
        time.sleep(cur_delay)

    try:
      frame_queue.put_nowait(frame)
    except Full:
      frame_queue.get()
      frame_queue.put(frame)

if __name__ == "__main__":
    # remote debugging (running in the container will listen on port 5678)
    debug = False
    local = False  # running raw python code

    if debug and not local:

        logging.info("Please attach a debugger to port 56780")

        import ptvsd
        ptvsd.enable_attach(('0.0.0.0', 56780))
        ptvsd.wait_for_attach()
        ptvsd.break_into_debugger()

    main()
