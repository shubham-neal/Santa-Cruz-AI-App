#FROM mcr.microsoft.com/azureml/o16n-sample-user-base/ubuntu-miniconda
FROM ubuntu:18.04

ARG CONDA_VERSION=4.8.2
ARG PYTHON_VERSION=3.7

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/miniconda/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        vim \
        wget \
        protobuf-compiler \
        cmake \
   && rm -rf /var/lib/apt/lists/*

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/miniconda && \
    rm ~/miniconda.sh && \
    /opt/miniconda/bin/conda clean -tipsy

RUN conda install -y conda=${CONDA_VERSION} python=${PYTHON_VERSION} && \
    conda clean -aqy && \
    rm -rf /opt/miniconda/pkgs && \
    find / -type d -name __pycache__ -prune -exec rm -rf {} \;

ARG CONDA_ENV=". /opt/miniconda/etc/profile.d/conda.sh"
ARG ENV_NAME=base
ARG ACTIVATE_ENV="$CONDA_ENV && conda activate $ENV_NAME"
ARG ENV_YAML=environment.yml
ARG TMP_FOLDER=/tmp_setup

ADD ${ENV_YAML} ${TMP_FOLDER}/

RUN ln -s /opt/miniconda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
  echo $ACTIVATE_ENV >> ~/.bashrc

RUN conda env update -f ${TMP_FOLDER}/${ENV_YAML} && \
conda clean -a -y
