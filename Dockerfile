FROM node:22-bookworm

# ---------- Build args ----------
ARG CLAUDE_VERSION=latest
ARG USER_UID=1000
ARG USER_GID=1000

# Optional language/tool layers — toggle via build args or .env.
ARG WITH_GO=0
ARG WITH_PYTHON=0
ARG WITH_RUST=0
ARG WITH_BUILD_ESSENTIAL=0
ARG EXTRA_APT_PACKAGES=""

# ---------- Environment ----------
ENV CLAUDE_CONFIG_DIR=/home/claude/.claude \
    GOPATH=/home/claude/go \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/usr/local/go/bin:/home/claude/go/bin:/usr/local/cargo/bin:$PATH

# ---------- Base apt packages (always) ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates openssh-client ripgrep jq less vim sudo \
    && rm -rf /var/lib/apt/lists/*

# ---------- Optional apt packages (single layer) ----------
RUN set -eux; \
    pkgs=""; \
    [ "$WITH_BUILD_ESSENTIAL" = "1" ] && pkgs="$pkgs build-essential"; \
    [ "$WITH_PYTHON" = "1" ]          && pkgs="$pkgs python3 python3-pip python3-venv build-essential"; \
    [ "$WITH_RUST" = "1" ]            && pkgs="$pkgs build-essential"; \
    [ -n "$EXTRA_APT_PACKAGES" ]      && pkgs="$pkgs $EXTRA_APT_PACKAGES"; \
    if [ -n "$pkgs" ]; then \
      apt-get update && apt-get install -y --no-install-recommends $pkgs \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# ---------- Optional: Go (latest) ----------
RUN if [ "$WITH_GO" = "1" ]; then \
      set -eux; \
      arch=$(dpkg --print-architecture); \
      ver=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1); \
      curl -fsSL "https://go.dev/dl/${ver}.linux-${arch}.tar.gz" | tar -C /usr/local -xz; \
    fi

# ---------- Optional: Rust (rustup, minimal profile) ----------
RUN if [ "$WITH_RUST" = "1" ]; then \
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --no-modify-path --profile minimal; \
    fi

# ---------- Non-root user ----------
RUN (getent group ${USER_GID} || groupadd --gid ${USER_GID} claude) \
 && (getent passwd ${USER_UID} || useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash claude) \
 && user=$(getent passwd ${USER_UID} | cut -d: -f1) \
 && echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
 && mkdir -p /home/claude && chown ${USER_UID}:${USER_GID} /home/claude

# ---------- Claude Code (native installer) ----------
ENV PATH=/home/claude/.local/bin:$PATH

USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- ${CLAUDE_VERSION}

WORKDIR /workspace

ENTRYPOINT ["claude"]
CMD ["--dangerously-skip-permissions"]
