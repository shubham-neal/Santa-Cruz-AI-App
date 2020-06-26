import os
import cv2
import logging
from ssd_object_detection import Detector
from videostream import VideoStream

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

def main_debug(displaying):
  video_file = os.path.join(os.path.dirname(__file__), "video/staircase.mp4")

  detector = Detector(use_gpu=True)
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

if __name__== "__main__":

  debug = True
  if debug:
    main_debug(False)

