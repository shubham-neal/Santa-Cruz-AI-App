ARG ACR_NAME_RTPT
FROM  ${ACR_NAME_RTPT}/base:latest-amd64

RUN apt-get update && apt-get install -y --no-install-recommends libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-doc \
    gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 \
    gstreamer1.0-qt5 gstreamer1.0-pulseaudio python3-dev \
    && rm -rf /var/lib/apt/lists/*

# add python requirements
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN pip3 install meson

RUN git clone https://github.com/GStreamer/gst-rtsp-server.git && cd gst-rtsp-server && git checkout 1.17.1

# COPY ./camera-stream /camera-stream
# RUN /bin/bash -c "chmod +x ./camera-stream/run_camera.sh"

# ENTRYPOINT [ "/bin/bash", "-c"]
# CMD  ["./camera-stream/run_camera.sh camera.py"]
