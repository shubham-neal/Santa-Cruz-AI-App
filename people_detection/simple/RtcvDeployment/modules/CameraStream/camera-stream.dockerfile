ARG CONTAINER_REGISTRY_LOGIN_SERVER
FROM  ${CONTAINER_REGISTRY_LOGIN_SERVER}/base

COPY ./camera-stream /camera-stream
RUN /bin/bash -c "chmod +x ./camera-stream/run_camera.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./camera-stream/run_camera.sh camera.py"]
