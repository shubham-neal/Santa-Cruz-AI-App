import os
import cv2
import logging
import time
from ssd_object_detection import Detector
#from ssd_object_detection_openvino import OpenVinoDetector
from videostream import VideoStream
import numpy as np
import json
from common import display

from flask import Flask, jsonify, request
# for HTTP/1.1 support
from werkzeug.serving import WSGIRequestHandler

app = Flask(__name__)

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

detector = Detector(use_gpu=True, people_only=True)
#detector = OpenVinoDetector(device_name="CPU")

def main_debug(displaying):
  video_file = os.path.join(os.path.dirname(__file__), "video/staircase.mp4")

  vid_stream = VideoStream(video_file, interval= 0.03)
  vid_stream.start()

  while True:
    _, frame = vid_stream.get_frame_with_id()
    detections = detector.detect(frame)
    #logging.info(detections)

    if not displaying:
      continue

    frame = display(frame, detections)
    # # check to see if the output frame should be displayed to our
    # # screen
    cv2.imshow("Frame", frame)

    key = cv2.waitKey(1) & 0xFF

    if key == ord('q') or key == 27:
      break
  
  cv2.destroyAllWindows()

def start_app():

    if debug:
      import ptvsd
      ptvsd.enable_attach(('0.0.0.0', 56781))
      ptvsd.wait_for_attach()
      ptvsd.break_into_debugger()

    # set protocol to 1.1 so we keep the connection open
    WSGIRequestHandler.protocol_version = "HTTP/1.1"

    app.run(debug=False, host="detector", port=5010)

@app.route("/lva", methods=["POST"])
def detect_in_frame_lva():
  

  imbytes = request.get_data()
  narr = np.frombuffer(imbytes, dtype='uint8')

  img = cv2.imdecode(narr, cv2.IMREAD_COLOR)
  
  detections = detector.detect(img)

  results = dict()
  results["inferences"] = detections
  return jsonify(results)

@app.route("/detect", methods=["POST"])
def detect_in_frame():
  # we are sending a json object

  start = time.time()

  data = request.get_json()
  frame = np.array(data['img']).astype('uint8')
  
  prep_time = time.time() - start

  results = {'frameId': data['frameId'], 'image_name': data['image_name']}
  detections = detector.detect(frame)

  total_time = time.time() - start
  detection_time = total_time - prep_time 

  perf = {"imgprep": prep_time, "detection": detection_time}

  results["detections"] = detections
  results["perf"] = perf
  
  logging.info(f"detected objects: {json.dumps(results, indent=1)}")
  return jsonify(results)

if __name__== "__main__":

  debug = False

  if debug:
    main_debug(True)
  else:
    start_app()  
  
