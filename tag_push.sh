#!/bin/sh

docker tag rtptofficial.azurecr.io/rgbtracking-node-dcs-may-release:0.8.1236.40 acrunifiededgedev001.azurecr.io/rgbtracking-node-dcs-may-release:0.8.1236.40
docker tag rtptofficial.azurecr.io/perceptionengine.iotedgelogs:manganese_20200212 acrunifiededgedev001.azurecr.io/perceptionengine.iotedgelogs:manganese_20200212
docker tag rtptofficial.azurecr.io/telegraf:1.0 acrunifiededgedev001.azurecr.io/telegraf:1.0

docker login --username acrunifiededgedev001 --password wmbq=hpAZd/JXf4iseesMwAds43zTinH acrunifiededgedev001.azurecr.io
docker push acrunifiededgedev001.azurecr.io/telegraf:1.0
docker push acrunifiededgedev001.azurecr.io/perceptionengine.iotedgelogs:manganese_20200212
docker push acrunifiededgedev001.azurecr.io/rgbtracking-node-dcs-may-release:0.8.1236.40
