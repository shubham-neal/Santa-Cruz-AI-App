import cv2
import os
import logging
import time, math
import json
import datetime
import numpy as np
from azure.storage.blob import BlobServiceClient
import requests
import threading
from streamer.videostream import VideoStream
from azure.iot.device.exceptions import ConnectionFailedError
import imutils
from net.ssd_object_detection import Detector

from messaging.iotmessenger import IoTInferenceMessenger

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

camera_config = None
received_twin_patch = False
twin_patch = None

def parse_twin(data):
  global camera_config, received_twin_patch

  logging.info(f"Retrieved updated properties: {data}")
  logging.info(data)

  if 'desired' in data:
    data = data['desired']

  if "cameras" in data:
    cams = data["cameras"].copy()
  blob = None

  # if blob is not specified we will message
  # the images to the IoT hub
  if "blob" in data:
    blob = data["blob"]

  camera_config = dict()
    
  camera_config["cameras"] = cams.copy()
  camera_config["blob"] = blob

  logging.info(f"config set: {camera_config}")
  received_twin_patch = False

def module_twin_callback(client):

  global twin_patch, received_twin_patch

  while True:
    # for debugging try and establish a connection
    # otherwise we don't care. If it can't connect let iotedge restart it
    twin_patch = client.receive_twin_desired_properties_patch()
    received_twin_patch = True

def main():
  global camera_config

  messenger = IoTInferenceMessenger()
  client = messenger.client

  twin_update_listener = threading.Thread(target=module_twin_callback, args=(client,))
  twin_update_listener.daemon = True
  twin_update_listener.start()

  blob_service_client = None

  # Should be properly asynchronous, but since we don't change things often
  # Wait for it to come back from twin update the very first time
  for i in range(20):
    if camera_config is None:
      time.sleep(0.5)
    break
  
  if camera_config is None:
    payload = client.get_twin()
    parse_twin(payload)

  logging.info("Created camera configuration from twin")

  while True:
    spin_camera_loop(messenger)
    parse_twin(twin_patch)

def spin_camera_loop(messenger):
  
  intervals_per_cam = dict()

  if camera_config["blob"] is not None:
    blob_service_client = BlobServiceClient.from_connection_string(camera_config["blob"])
    logging.info(f"Created blob service client: {blob_service_client.account_name}")

  while not received_twin_patch:

    for key, cam in camera_config["cameras"].items():

      if not cam["enabled"]:
          continue

      curtime = time.time()
      
      if key not in intervals_per_cam:
        intervals_per_cam[key] = dict()
        current_source = intervals_per_cam[key]
        current_source['timer'] = 0
        current_source['rtsp'] = cam['rtsp']
        current_source['interval'] = float(cam['interval'])
        current_source['video'] = VideoStream(cam['rtsp'], float(cam['interval']))
        current_source['video'].start()

        #TODO: This should not be here.
        current_source['detector'] = Detector(cam['gpu'])

      # this will keep track of how long we need to wait between
      # bursts of activity
      video_streamer = current_source['video']

      # not enough time has passed since the last collection
      if curtime - current_source['timer'] < float(cam['interval']):
          continue

      current_source['timer'] = curtime

      # block until we get something
      frame_id, img = video_streamer.get_frame_with_id()
      if img is None:
        logging.warn("No frame retrieved. Is video running?")
        continue

      logging.info(f"Grabbed frame {frame_id} from {cam['rtsp']}")

      camId = f"{cam['space']}/{key}"

      # send to blob storage and retrieve the timestamp by which we will identify the video
      curtimename = None
      if camera_config["blob"] is not None:
          curtimename, _ = send_img_to_blob(blob_service_client, img, camId)

      # TODO: queue up detections
      detections = []
      if cam['detector'] is not None and cam['inference'] is not None and cam['inference']:
        #detections = infer(cam['detector'], img, frame_id, curtimename)
        detections = current_source['detector'].detect(img)
        
      # message the image capture upstream
      if curtimename is not None:
        messenger.send_image_and_detection(camId, curtimename, frame_id, detections)
        logging.info(f"Notified of image upload: {cam['rtsp']} to {cam['space']}")

  # shutdown current video captures
  for key, cam in intervals_per_cam.items():
    cam['video'].stop()

def infer(detector, img, frame_id, img_name):

  im = imutils.resize(img, width=400)

  data = json.dumps({"frameId": frame_id, "image_name": img_name, "img": im.tolist()})
  headers = {'Content-Type': "application/json"}
  start = time.time()
  resp = requests.post(detector, data, headers=headers)
  proc_time = time.time() - start
  resp.raise_for_status()
  result = resp.json()

  return result["detections"]


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

if __name__ == "__main__":
    # remote debugging (running in the container will listen on port 5678)
    debug = False

    if debug:

        logging.info("Please attach a debugger to port 56780")

        import ptvsd
        ptvsd.enable_attach(('0.0.0.0', 56780))
        ptvsd.wait_for_attach()
        ptvsd.break_into_debugger()

    main()
