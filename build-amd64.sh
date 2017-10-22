#!/bin/bash

SEAFILE_VERSION=${1:-6.2.2}

DOCKER_BASE_IMAGE=debian:stretch-slim

docker build \
       --tag nikoglyph/seafile-server:${SEAFILE_VERSION} \
       --tag nikoglyph/seafile-server:latest \
       --build-arg DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE} \
       --build-arg SEAFILE_VERSION=${SEAFILE_VERSION} \
       .
