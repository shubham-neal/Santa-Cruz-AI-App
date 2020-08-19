ARG ACR_NAME
ARG IMAGE_BASE 

FROM  ${ACR_NAME}/${IMAGE_BASE}_base:latest-amd64

RUN pip3 install Flask

COPY ./detector /detector
RUN /bin/bash -c "chmod +x /detector/run_detector.sh"

ENTRYPOINT ["/bin/bash", "-c"]
CMD  ["/detector/run_detector.sh detector.py"]
