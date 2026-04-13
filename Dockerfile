FROM node:20-bookworm

ARG CLAUDE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    openssh-client \
    ripgrep \
    jq \
    less \
    vim \
    sudo \
    python3 \
    python3-pip \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user matching common host UID/GID
ARG USER_UID=1000
ARG USER_GID=1000
RUN (getent group ${USER_GID} || groupadd --gid ${USER_GID} claude) \
 && (getent passwd ${USER_UID} || useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash claude) \
 && CLAUDE_USER=$(getent passwd ${USER_UID} | cut -d: -f1) \
 && echo "${CLAUDE_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
 && mkdir -p /home/claude && chown ${USER_UID}:${USER_GID} /home/claude

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION}

USER claude
WORKDIR /workspace

# Claude config dir is set at runtime to a persistent auth volume (see run.sh / compose).
ENV CLAUDE_CONFIG_DIR=/home/claude/.claude

ENTRYPOINT ["claude"]
CMD []
