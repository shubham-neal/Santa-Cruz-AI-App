ARG ACR_NAME_RTPT
FROM  ${ACR_NAME_RTPT}/opencv_base:latest-amd64

COPY ./detector /detector
RUN /bin/bash -c "chmod +x ./detector/run_detector.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./detector/run_detector.sh detector.py"]
