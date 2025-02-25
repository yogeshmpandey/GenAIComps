#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -x

WORKPATH=$(dirname "$PWD")
ip_address=$(hostname -I | awk '{print $1}')

function build_docker_images() {
    cd $WORKPATH
    echo $(pwd)
    docker build --no-cache -t opea/text2image-gaudi:latest -f comps/text2image/src/Dockerfile.intel_hpu .
    if [ $? -ne 0 ]; then
        echo "opea/text2image-gaudi built fail"
        exit 1
    else
        echo "opea/text2image-gaudi built successful"
    fi
}

function start_service() {
    unset http_proxy
    docker run -d -p 9379:9379 --name="test-comps-text2image-gaudi" --runtime=habana -e HABANA_VISIBLE_DEVICES=all -e OMPI_MCA_btl_vader_single_copy_mechanism=none --cap-add=sys_nice --ipc=host -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e HF_TOKEN=$HF_TOKEN -e MODEL=stabilityai/stable-diffusion-xl-base-1.0 opea/text2image-gaudi:latest
    sleep 30s
}

function validate_microservice() {
    result=$(http_proxy="" curl http://localhost:9379/v1/text2image -XPOST -d '{"prompt":"An astronaut riding a green horse", "num_images_per_prompt":1}' -H 'Content-Type: application/json')
    if [[ $result == *"images"* ]]; then
        echo "Result correct."
    else
        echo "Result wrong."
        docker logs test-comps-text2image-gaudi
        exit 1
    fi

}

function stop_docker() {
    cid=$(docker ps -aq --filter "name=test-comps-text2image*")
    if [[ ! -z "$cid" ]]; then docker stop $cid && docker rm $cid && sleep 1s; fi
}

function main() {

    stop_docker

    build_docker_images
    start_service

    validate_microservice

    stop_docker
    echo y | docker system prune

}

main
