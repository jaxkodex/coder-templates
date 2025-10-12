FROM ubuntu:22.04

# Install essential packages and Coder dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    # Coder agent requirements
    curl \
    wget \
    ca-certificates \
    openssh-client \
    # Development tools
    git \
    vim \
    nano \
    sudo \
    # Build essentials
    build-essential \
    # Additional utilities
    htop \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Create coder user with sudo access
RUN useradd -m -s /bin/bash coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder && \
    chmod 0440 /etc/sudoers.d/coder

# Set up home directory
USER coder
WORKDIR /home/coder

# Create .bashrc with helpful defaults
RUN echo 'export PS1="\[\e[32m\]\u@\h:\[\e[34m\]\w\[\e[0m\]\$ "' >> ~/.bashrc && \
    echo 'alias ll="ls -lah"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc

# Expose common development ports
EXPOSE 8080 3000 5000

CMD ["/bin/bash"]
