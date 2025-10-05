FROM ubuntu:noble

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    vim \
    sudo \
    zsh \
    nodejs \
    npm \
    busybox-static \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for busybox ash to make it easily accessible
RUN ln -sf /bin/busybox /usr/local/bin/ash \
    && ln -sf /bin/busybox /usr/local/bin/busybox
