#!/bin/bash

docker build -t cloudykit:latest .
docker run \
    --rm \
    -it \
    -v $(PWD)/Sources:/CloudyKit/Sources \
    -v $(PWD)/Tests:/CloudyKit/Tests \
    -v $(PWD)/Package.swift:/CloudyKit/Package.swift \
    -w /CloudyKit \
    cloudykit:latest swift test
