ARG ACR_NAME_RTPT
FROM  ${ACR_NAME_RTPT}/opencv_base:latest-amd64

COPY ./camera-stream /camera-stream
RUN /bin/bash -c "chmod +x ./camera-stream/run_camera.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./camera-stream/run_camera.sh camera.py"]
