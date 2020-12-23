#!/bin/bash

docker build -t cloudykit:latest .
docker run --rm -it -v $(PWD):/CloudyKit -w /CloudyKit cloudykit:latest swift test
