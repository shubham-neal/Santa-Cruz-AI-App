import os
import cv2
import logging
from ssd_object_detection import Detector
from videostream import VideoStream
import numpy as np

from flask import Flask, jsonify, request
# for HTTP/1.1 support
from werkzeug.serving import WSGIRequestHandler

app = Flask(__name__)

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

detector = Detector(use_gpu=True)

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

    frame = detector.display(frame, detections)
    # # check to see if the output frame should be displayed to our
    # # screen
    cv2.imshow("Frame", frame)

    key = cv2.waitKey(1) & 0xFF

    if key == ord('q') or key == 27:
      break
  
  cv2.destroyAllWindows()

def start_app():
    # set protocol to 1.1 so we keep the connection open
    WSGIRequestHandler.protocol_version = "HTTP/1.1"

    #app.run(debug=False, host="0.0.0.0", port=5010)
    app.run(debug=False, host="detector", port=5010)

@app.route("/detect", methods=["POST"])
def detect_in_frame():
  # we are sending a json object
  data = request.get_json()
  frame = np.array(data['img']).astype('uint8')

  results = {'frameId': data['frameId'], 'image_name': data['image_name']}
  detections = detector.detect(frame)

  results["detections"] = detections
  return jsonify(results)

if __name__== "__main__":

  debug = False

  if debug:
    main_debug(False)

  start_app()  
  
