import cv2
import os, logging, time, json, datetime
import numpy as np
from azure.storage.blob import BlobServiceClient
import requests

from messaging.iotmessenger import IoTInferenceMessenger

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
    level=logging.INFO)

camera_config = None
intervals_per_cam = dict()

def module_twin_callback(update_state, payload, user_context):
    global camera_config

    data = json.loads(payload)
    logging.info(f"Retrieved updated properties: {data}")

    #after the first time there will be no "desired" entry    
    if "desired" in data:
        data = data["desired"]
    logging.info(f"desired properties: {data}")

    cams = data["cameras"]
    blob = data["blob"]

    camera_config = dict()
    camera_config["cameras"] = cams
    camera_config["blob"] = blob

    logging.info(f"config set: {camera_config}")
    return 0

def main():
    global camera_config

    if local or debug:
        # if we are not local this will be overridden anyway
        fn = os.path.join(os.path.dirname(__file__), "desired.json")

        with open(fn, "r") as f:
            camera_config = json.load(f)

    messenger = None
    if not local:
        messenger = IoTInferenceMessenger()
        client = messenger.client

        if not debug:
            client.set_module_twin_callback(module_twin_callback, 0)
    
    blob_service_client = None

    while True:
        # Should be properly asynchronous, but since we don't change things often
        if camera_config is None or "cameras" not in camera_config or "blob" not in camera_config:
            time.sleep(5)
            continue
        if blob_service_client is None:
            blob_service_client = BlobServiceClient.from_connection_string(camera_config["blob"])
            logging.info(f"Created blob service client: {blob_service_client.account_name}")

        for key, cam in camera_config["cameras"].items():
            logging.info(f"Processing camera: {key}")

            if not cam["enabled"]:
                continue

            curtime = time.time()
            
            # not enough time has passed since the last collection
            if key in intervals_per_cam and curtime - intervals_per_cam[key] < cam["interval"]:
                logging.info(f"Waiting {cam['interval'] - (curtime - intervals_per_cam[key])} for {key}")
                continue

            if local:
                vid_file = os.path.join(os.path.dirname(__file__), cam["rtsp"])
            else:
                vid_file = cam["rtsp"]
            img = grab_image_from_stream(vid_file)
            logging.info(f"Grabbed image from {cam['rtsp']}")

            camId= f"{cam['counter']}/{key}"
            curtimename, full_cam_id = send_img_to_blob(blob_service_client, img, camId)
            
            if "inference" in cam and cam["inference"]:
                if "detector" not in cam:
                    logging.error(f"Cannot perform inference: detector not specified for camera {key}")
                else:
                    infer_and_report(messenger, full_cam_id, cam["detector"], img, curtimename)

            logging.info(f"Sent {cam['rtsp']} to {cam['counter']}")

            # update collection time for camera
            intervals_per_cam[key] = curtime

        time.sleep(1)

def infer_and_report(messenger, cam_id, detector, img, curtimename):
    try:
        classes, scores, boxes, proc_time = infer(detector, img)

        if local:
            return

        report(messenger, cam_id, classes, scores, boxes, curtimename, proc_time)

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

def send_img_to_blob(blob_service_client, img, camId):

    curtime = datetime.datetime.utcnow()
    name = f"{curtime.isoformat()}Z"
    local_name = os.path.abspath(curtime.strftime("%Y_%m_%d_%H_%M_%S_%f")[:-4] + ".jpg")
    day=curtime.strftime("%Y-%m-%d")
    blob_client = blob_service_client.get_blob_client("still-images", f"{camId}/{day}/{name}.jpg")
    cv2.imwrite(local_name, img)
    with open(local_name, "rb") as data:
        blob_client.upload_blob(data)

    os.remove(local_name)
    return name, f"{camId}/{day}"

def grab_image_from_stream(cam):

    repeat = 3
    wait = 3
    frame = None

    for _ in range(repeat):

        try:
            video_capture = cv2.VideoCapture(cam)
            video_capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            
            frame = video_capture.read()[1]
            video_capture.release()
            break
        except:
            # try to re-capture the stream
            logging.info("Could not capture video. Recapturing and retrying...")
            time.sleep(wait)

    if frame is None:               
        logging.info("Failed to capture frame, sending blank image")
        frame = np.zeros((300, 300, 3))

    return frame

if __name__ == "__main__":
    debug = False
    local = False

    if debug and not local:

        logging.info("Please attach a debugger to port 5678")
        
        import ptvsd
        ptvsd.enable_attach(('0.0.0.0', 5678))
        ptvsd.wait_for_attach()
        ptvsd.break_into_debugger()

    main()
