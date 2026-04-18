FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ca-certificates \
    cmake \
    file \
    g++ \
    gcc \
    git \
    make \
    ninja-build \
    openssh-client \
    perl \
    python3 \
    rsync \
    xz-utils \
    zip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["zsh"]
