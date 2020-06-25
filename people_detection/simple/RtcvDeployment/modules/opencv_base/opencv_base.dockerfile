#FROM mcr.microsoft.com/azureml/o16n-sample-user-base/ubuntu-miniconda
FROM nvcr.io/nvidia/cuda:10.2-devel-ubuntu18.04

# ARG CONDA_VERSION=py37_4.8.2
# ARG PYTHON_VERSION=3.7

# ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
# ENV PATH /opt/conda/bin:$PATH


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
        libxext6 \
        libxrender1 \
        vim \
        wget \
        protobuf-compiler \
        cmake \
        python3-dev \
   && rm -rf /var/lib/apt/lists/*
