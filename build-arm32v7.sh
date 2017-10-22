#!/bin/bash

SEAFILE_VERSION=${1:-6.2.2}

DOCKER_BASE_IMAGE=arm32v7/debian:stretch-slim
SEAFILE_DOWNLOAD_URL=https://github.com/haiwen/seafile-rpi/releases/download/v${SEAFILE_VERSION}
SEAFILE_ARCH_QUALIFIER=stable_pi

docker build \
       --tag nikoglyph/arm32v7/seafile-server:${SEAFILE_VERSION} \
       --tag nikoglyph/arm32v7/seafile-server:latest \
       --build-arg DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE} \
       --build-arg SEAFILE_VERSION=${SEAFILE_VERSION} \
       --build-arg SEAFILE_DOWNLOAD_URL=${SEAFILE_DOWNLOAD_URL} \
       --build-arg SEAFILE_ARCH_QUALIFIER=${SEAFILE_ARCH_QUALIFIER} \
       .
