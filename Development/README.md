---
display_name: Development
description: A Docker-based development environment that builds from a Dockerfile
icon: ../../../site/static/emojis/1f4e6.png
maintainer_github: coder
verified: true
tags: [docker, development]
---

# Development Docker Template

A Coder template that builds a custom Docker image from a Dockerfile, providing a flexible and customizable development environment.

## Features

- Builds a Docker image from a local Dockerfile
- Persistent home directory using Docker volumes
- Code-server pre-installed for browser-based development
- Automatic rebuild when Dockerfile changes
- Full customization of the development environment

## Prerequisites

- Docker installed and running on the Coder host
- Docker socket accessible to Coder (default: `/var/run/docker.sock`)

## Usage

### Basic Setup

1. Push this template to your Coder deployment
2. Create a new workspace from the template
3. The Docker image will be built automatically from the Dockerfile
4. Access your workspace through code-server

### Customizing the Dockerfile

Edit the `Dockerfile` in this directory to customize your development environment:

```dockerfile
# Change the base image
FROM ubuntu:22.04

# Install additional packages
RUN apt-get update && apt-get install -y \
    python3 \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Add custom configurations
COPY custom-config /home/coder/.config/
```

The Docker image will automatically rebuild when you update the Dockerfile.

### Configuration Options

#### Docker Socket

If your Docker socket is not at the default location, specify it using the `docker_socket` variable:

```bash
coder templates push --variable docker_socket=/path/to/docker.sock
```

Or set it when creating the template in the Coder UI.

## Template Structure

- **Dockerfile**: Defines the container environment
- **main.tf**: Terraform configuration for the workspace
- **README.md**: This file

## Customization Examples

### Adding Node.js

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs
```

### Adding Python with pip

```dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip && \
    rm -rf /var/lib/apt/lists/*
```

### Adding Go

```dockerfile
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz && \
    rm go1.21.0.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
```

## Persistent Storage

User home directories (`/home/coder`) are stored in Docker volumes and persist across workspace restarts and rebuilds.

## Troubleshooting

### Image build fails

Check the Dockerfile syntax and ensure all required packages are available in the base image repositories.

### Cannot connect to Docker daemon

Verify that:
1. Docker is running on the Coder host
2. The Coder process has access to the Docker socket
3. The `docker_socket` variable is correctly configured

### Workspace fails to start

Check the Coder logs for errors related to container creation. Common issues include:
- Insufficient resources
- Port conflicts
- Volume mounting errors
