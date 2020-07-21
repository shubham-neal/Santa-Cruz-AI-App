ARG ACR_NAME
FROM  ${ACR_NAME}/opencv_base:latest-arm64v8

RUN pip3 install Flask

COPY ./detector /detector
RUN /bin/bash -c "chmod +x ./detector/run_detector.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./detector/run_detector.sh detector.py"]
