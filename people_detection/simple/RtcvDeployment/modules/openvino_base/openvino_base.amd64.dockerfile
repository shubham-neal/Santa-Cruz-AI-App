FROM openvino/ubuntu18_runtime:2020.4 

# Install Git and clone OMZ (OpenVINO Model Zoo)
RUN apt-get update -y && \ 
    apt-get install -y --no-install-recommends git && \
    git clone https://github.com/openvinotoolkit/open_model_zoo $INTEL_OPENVINO_DIR/omz && \
    apt-get clean && \
    apt-get purge -y --auto-remove git

# copy requirements
COPY requirements.txt /tmp/

# add python requirements
RUN pip3 install -r /tmp/requirements.txt && \
        apt-get clean
