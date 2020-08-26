#! /bin/bash

cd /detector
ARGS=$@

# check for openvino
if [[ ! -z "$INTEL_OPENVINO_DIR" ]]; then 
    source $INTEL_OPENVINO_DIR/bin/setupvars.sh
    udevadm control --reload-rules
    udevadm trigger
    ldconfig
fi

python3 $ARGS