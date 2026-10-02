# Build host for Yocto Project 5.0 "scarthgap"
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        gawk wget git diffstat unzip texinfo gcc g++ build-essential chrpath socat \
        cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping \
        python3-git python3-jinja2 python3-subunit zstd liblz4-tool lz4 file locales \
        libacl1 sudo ca-certificates bzip2 vim-tiny bmap-tools \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# BitBake refuses to run as root
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} builder && useradd -m -u ${UID} -g ${GID} -s /bin/bash builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/builder

USER builder
WORKDIR /work
