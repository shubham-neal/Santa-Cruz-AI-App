ARG ACR_NAME
FROM  ${ACR_NAME}/opencv_base:latest-arm64v8

COPY ./camera-stream /camera-stream
RUN /bin/bash -c "chmod +x ./camera-stream/run_camera.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./camera-stream/run_camera.sh camera.py"]
