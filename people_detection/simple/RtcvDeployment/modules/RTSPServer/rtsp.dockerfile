ARG ACR_NAME_RTPT
FROM  ${ACR_NAME_RTPT}/base:latest-amd64

RUN apt-get update && apt-get install -y --no-install-recommends libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl \
    gstreamer1.0-pulseaudio gstreamer1.0-rtsp libgstrtspserver-1.0 \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get remove -y --purge cmake

ADD https://www.openssl.org/source/openssl-1.1.0f.tar.gz /tmp
RUN tar -zxvf /tmp/openssl-1.1.0f.tar.gz -C /tmp/
RUN cd /tmp/openssl-1.1.0f && ./config -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)' && make -j $(nproc) && make install

ADD https://github.com/Kitware/CMake/releases/download/v3.16.5/cmake-3.16.5.tar.gz /tmp/
RUN tar -zxvf /tmp/cmake-3.16.5.tar.gz -C /tmp/
RUN cd /tmp/cmake-3.16.5 && ./bootstrap && make -j $(nproc) && make install 

RUN mkdir RTSPServer
COPY ./CMakeLists.txt RTSPServer/
ADD ./src RTSPServer/src

RUN cd RTSPServer && mkdir build && cd build && cmake .. && make

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["./RTSPServer/build/rtspserver /tmp/video/caffeteria.mp4"]
