FROM swift:6.0.3

RUN apt-get update && apt-get install -y \
  openssl \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*
