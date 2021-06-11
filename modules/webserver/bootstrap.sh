#!/bin/bash

sleep 30

snap install docker
systemctl enable snap.docker.dockerd
systemctl start snap.docker.dockerd

sleep 30

docker run -d -p 80:80 --net host \
    -e F5DEMO_APP=website \
    -e F5DEMO_NODENAME="${NODENAME}" \
    -e F5DEMO_COLOR=${COLOR} \
    --restart always \
    --name f5demoapp \
    f5devcentral/f5-demo-httpd:nginx