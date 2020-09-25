# Deployment Requirements

Files and structures needed for building and deploying the OpenCV-based solution

## Directories Required

Directories not mentioned may be removed

1. current_root -> modules
2. current_root -> modules -> opencv_base, Detector, CameraStream

## Files Required

deployment.camera.template.json
.env

## Structure of the .env file

```sh
# Azure Container Registry Properties
ACR_NAME=mxsandbox.azurecr.io
ACR_PASSWORD=YT6Hv=kiANSe=yjuI2EiYcvP0Cgeg3Db
ACR_USERNAME=mxsandbox

# Camera Build/Deploy properties
CAMERA_CONTAINER_IMAGE_TAG=0.1
CAMERA_BLOB_SAS=BlobEndpoint=https://storageperfmetricsvm.blob.core.windows.net/;SharedAccessSignature=se=2021-08-13T21%3A11Z&sp=rwlac&sv=2018-03-28&ss=b&srt=sco&sig=tE8fWILrFtBetLxppikBKmqdNldz66zRweSfH8/WYZE%3D

CROSSING_VIDEO_URL="/camera-stream/video/sample-video.mp4"

# runc or nvidia if running on a device with NVIDIA GPU and NVIDIA docker runtime is installed
RUNTIME=runc

# Detector URL: constant
PEOPLE_DETECTOR=http://detector:5010/detect

# Base image from which CameraStream and Detector images are built
IMAGE_BASE=opencv

# Inference and upload frequencies
UPLOAD_FREQ_SEC=0.2
DISPLAY=:1
```