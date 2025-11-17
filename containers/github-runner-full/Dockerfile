FROM ghcr.io/actions/actions-runner:latest

# Switch to root to install packages
USER root

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/usr/local/go/bin:${PATH}" \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo

# Update package list and install base utilities
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    jq \
    zip \
    unzip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    file \
    sudo \
    openssh-client \
    vim \
    nano \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Python (3.11, 3.12, 3.13)
# ============================================================================
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python3.13 \
    python3.13-dev \
    python3.13-venv \
    python3-pip \
    pipx \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.13 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.13 1

# Bootstrap pip for Python 3.13 (distutils removed in 3.12+)
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    ln -sf /usr/local/bin/pip3.13 /usr/local/bin/pip3 && \
    ln -sf /usr/local/bin/pip3.13 /usr/local/bin/pip

# Install common Python tools
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir \
    poetry \
    virtualenv \
    tox \
    pytest \
    black \
    ruff \
    mypy

# Install uv (fast Python package installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    cp /root/.local/bin/uv /usr/local/bin/uv && \
    cp /root/.local/bin/uvx /usr/local/bin/uvx && \
    chmod +x /usr/local/bin/uv /usr/local/bin/uvx

# ============================================================================
# libpostal (address parsing/normalization library)
# ============================================================================
# Install libpostal build dependencies and C library from master branch
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    libtool \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Clone and build libpostal C library (no version pinning - master branch)
RUN git clone https://github.com/openvenues/libpostal /tmp/libpostal && \
    cd /tmp/libpostal && \
    ./bootstrap.sh && \
    ./configure --datadir=/usr/local/share/libpostal && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/libpostal

# Download libpostal address parsing data (~1.5GB)
RUN mkdir -p /usr/local/share/libpostal && \
    /usr/local/bin/libpostal_data download all /usr/local/share/libpostal

# Install Python bindings for libpostal
RUN pip3 install --no-cache-dir postal

# ============================================================================
# Node.js (LTS - v20)
# ============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install common Node.js tools
RUN npm install -g \
    yarn \
    pnpm \
    npm-check-updates \
    typescript \
    ts-node \
    eslint \
    prettier

# ============================================================================
# Go (latest stable)
# ============================================================================
RUN GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n1) && \
    wget -q https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf ${GO_VERSION}.linux-amd64.tar.gz && \
    rm ${GO_VERSION}.linux-amd64.tar.gz

# ============================================================================
# Rust (stable toolchain)
# ============================================================================
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    $CARGO_HOME/bin/rustup component add clippy rustfmt && \
    cp $CARGO_HOME/bin/* /usr/local/bin/ && \
    chmod -R a+r /opt/rustup /opt/cargo && \
    chmod a+x /usr/local/bin/rustc /usr/local/bin/cargo /usr/local/bin/rustup /usr/local/bin/rustfmt /usr/local/bin/cargo-clippy

# ============================================================================
# Ruby (latest stable)
# ============================================================================
RUN apt-get update && apt-get install -y \
    ruby-full \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler

# ============================================================================
# Java (OpenJDK 17 LTS)
# ============================================================================
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    maven \
    gradle \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# .NET (8.0 LTS)
# ============================================================================
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-8.0 && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# Nix (multi-user installation)
# ============================================================================
RUN curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh && \
    bash /tmp/nix-install.sh --daemon && \
    rm /tmp/nix-install.sh && \
    echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' >> /etc/profile

# ============================================================================
# Docker CLI
# ============================================================================
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# Docker Compose
# ============================================================================
RUN COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name) && \
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# ============================================================================
# GitHub CLI
# ============================================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# Terraform
# ============================================================================
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# kubectl
# ============================================================================
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && apt-get install -y kubectl && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# Helm
# ============================================================================
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ============================================================================
# AWS CLI
# ============================================================================
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# ============================================================================
# Azure CLI
# ============================================================================
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# ============================================================================
# Google Cloud SDK
# ============================================================================
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-cli && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# Additional development tools
# ============================================================================
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    tk-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# PostgreSQL Client & Development Libraries
# ============================================================================
RUN apt-get update && apt-get install -y \
    postgresql-client \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Set up runner user with sudo access
# ============================================================================
RUN echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Add Go and Nix to runner user profile
RUN echo 'export PATH="/usr/local/go/bin:${PATH}"' >> /home/runner/.bashrc && \
    echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' >> /home/runner/.bashrc

# Switch back to runner user
USER runner

# Set working directory
WORKDIR /home/runner

# Verify installations (commented out for local ARM64 builds)
# Uncomment to verify on amd64 systems
# RUN python3 --version && \
#     uv --version && \
#     python3 -c "import postal; print('libpostal Python bindings OK')" && \
#     node --version && \
#     npm --version && \
#     go version && \
#     rustc --version && \
#     cargo --version && \
#     ruby --version && \
#     java -version && \
#     dotnet --version && \
#     docker --version && \
#     docker-compose --version && \
#     psql --version && \
#     gh --version && \
#     terraform --version && \
#     kubectl version --client && \
#     helm version && \
#     aws --version && \
#     az version && \
#     gcloud --version
