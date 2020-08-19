ARG ACR_NAME
ARG IMAGE_BASE

FROM  ${ACR_NAME}/${IMAGE_BASE}_base:latest-arm64v8

RUN pip3 install Flask

COPY ./detector /detector
RUN /bin/bash -c "chmod +x ./detector/run_detector.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./detector/${IMAGE_BASE}_run_detector.sh detector.py"]
