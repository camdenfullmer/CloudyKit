#!/bin/bash

docker run --rm -it -v $(PWD):/CloudyKit -w /CloudyKit swift:5.3 swift test
