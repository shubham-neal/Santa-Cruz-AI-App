FROM arm64v8/ubuntu:18.04

# update the OS
RUN apt-get upgrade && apt-get update && apt-get install -y  \
        build-essential \
        unzip \
        pkg-config \
        bzip2 \
        ca-certificates \
        libjpeg-dev libpng-dev libtiff-dev \
        libavcodec-dev libavformat-dev libswscale-dev \
        libv4l-dev libxvidcore-dev libx264-dev \
        libgtk-3-dev \
        libatlas-base-dev gfortran \
        curl \
        libglib2.0-0 \
        libsm6 \
        libssl-dev \
        libffi-dev \
        libxext6 \
        libxrender1 \
        vim \
        wget \
        protobuf-compiler \
        python3-dev \
   && rm -rf /var/lib/apt/lists/*

RUN wget -O cmake-3.18.2.tar.gz https://github.com/Kitware/CMake/releases/download/v3.18.2/cmake-3.18.2.tar.gz && \
        tar -xvf cmake-3.18.2.tar.gz && \
        cd cmake-3.18.2 && \
        ./bootstrap && make -j${nproc} && make install && \
        cd .. && rm cmake-3.18.2.tar.gz

# download opencv
RUN  wget -O opencv.zip https://github.com/opencv/opencv/archive/4.2.0.zip && unzip opencv.zip && mv opencv-4.2.0 opencv
# RUN wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.2.0.zip && unzip opencv_contrib.zip && mv opencv_contrib-4.2.0 opencv_contrib

# copy requirements
COPY requirements.txt /tmp/

# add python requirements
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN pip install -r /tmp/requirements.txt

# build opencv
RUN cd /opencv && mkdir build && cd build && \
   cmake -D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=/usr/local \
	-D INSTALL_PYTHON_EXAMPLES=OFF \
	-D INSTALL_C_EXAMPLES=OFF \
	-D OPENCV_ENABLE_NONFREE=OFF \
	-D WITH_CUDA=OFF \
	-D WITH_CUDNN=OFF \
	-D OPENCV_DNN_CUDA=OFF \
	-D HAVE_opencv_python3=ON \
        -D PYTHON_DEFAULT_EXECUTABLE=$(which python3) \
	-D PYTHON_EXECUTABLE=$(which python3) \
        -D BUILD_TESTS=OFF \
        -D BUILD_PERF_TESTS=OFF \
        -D BUILD_opencv_python_tests=OFF \
	-D BUILD_EXAMPLES=OFF ..

RUN cd /opencv/build && make -j $(nproc) && make install && ldconfig      

ENV OpenCV_DIR /opencv/build

RUN apt-get update && apt-get install -y \
         git \
        libboost-regex-dev \
        libgtk2.0-dev \
        automake \
        libtool \
        autoconf \
        libcairo2-dev \
        libpango1.0-dev \
        libglib2.0-dev \
        libgstreamer1.0-0 \
        gstreamer1.0-plugins-base \
        libpng-dev

# libusb
RUN usermod -aG users root
WORKDIR /opt
RUN curl -L https://github.com/libusb/libusb/archive/v1.0.22.zip --output v1.0.22.zip && \
    unzip v1.0.22.zip

WORKDIR /opt/libusb-1.0.22

RUN ./bootstrap.sh && \
    ./configure --disable-udev --enable-shared && \
    make -j$(nproc)

RUN apt-get update && \
    apt-get install -y --no-install-recommends libusb-1.0-0-dev=2:1.0.21-2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/libusb-1.0.22/libusb
RUN /bin/mkdir -p '/usr/local/lib' && \
    /bin/bash ../libtool --mode=install /usr/bin/install -c   libusb-1.0.la '/usr/local/lib' && \
    /bin/mkdir -p '/usr/local/include/libusb-1.0' && \
    /usr/bin/install -c -m 644 libusb.h '/usr/local/include/libusb-1.0' && \
    /bin/mkdir -p '/usr/local/lib/pkgconfig'
WORKDIR /opt/libusb-1.0.22/
RUN /usr/bin/install -c -m 644 libusb-1.0.pc '/usr/local/lib/pkgconfig' && \
    ldconfig && \
    ln -fs /usr/local/lib/libusb-1.0.so.0.1.0 /lib/aarch64-linux-gnu/libusb-1.0.so.0

WORKDIR /

RUN git clone https://github.com/openvinotoolkit/openvino.git && \ 
        cd /openvino/inference-engine && \
        git submodule update --init --recursive 

# openvino
RUN cd /openvino && \
        mkdir build && cd build && \
        cmake -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_MKL_DNN=OFF \
        -DENABLE_CLDNN=ON \
        -DENABLE_GNA=OFF \
        -DENABLE_SSE42=OFF \
        -DTHREADING=SEQ \
        -DOpenCV_DIR=${OpenCV_DIR} \
        -DENABLE_SAMPLES=ON \
        -DENABLE_PYTHON=ON \
        -DENABLE_OPENCV=OFF \
        -DPYTHON_EXECUTABLE=$(which python3) \
        -DPYTHON_LIBRARY=/usr/lib/python3.6/config-3.6m-aarch64-linux-gnu/libpython3.6m.so \
        -DPYTHON_INCLUDE_DIR=/usr/include/python3.6   \     
        .. && \
        make -j$(nproc) && make install && ldconfig

ENV INTEL_OPENVINO_DIR /usr/local

WORKDIR /
RUN cp /usr/local/lib/libusb-1.0.so.0.1.0 /lib/aarch64-linux-gnu/libusb-1.0.so.0