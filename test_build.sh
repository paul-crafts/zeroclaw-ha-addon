#!/bin/bash
docker pull ghcr.io/home-assistant/aarch64-base:latest
docker run --rm ghcr.io/home-assistant/aarch64-base:latest which apt-get
