#!/usr/bin/env bash
# Launcher: mounts the target directory into the container as /workspace,
# plus a persistent auth dir so subscription login survives between runs.
# No SSH keys, gitconfig, or host env vars leak in.
set -euo pipefail

IMAGE="claude-code:local"
DIR="${1:-$PWD}"
DIR="$(cd "$DIR" && pwd)"

# Persistent Claude auth lives here on the host — NOT inside your project.
AUTH_DIR="${CLAUDE_DOCKER_AUTH_DIR:-$HOME/.claude-docker-auth}"
mkdir -p "$AUTH_DIR"
chmod 700 "$AUTH_DIR"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE..."
  docker build \
    --build-arg USER_UID="$(id -u)" \
    --build-arg USER_GID="$(id -g)" \
    -t "$IMAGE" \
    "$(dirname "$0")"
fi

docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --read-only \
  --tmpfs /tmp:size=256m \
  --tmpfs /home/claude/.npm:size=256m \
  --tmpfs /home/claude/.cache:size=256m \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  --pids-limit 512 \
  --memory 4g \
  --env-file /dev/null \
  -e TERM=xterm-256color \
  -e CLAUDE_CONFIG_DIR=/home/claude/.claude \
  -v "$AUTH_DIR":/home/claude/.claude \
  -v "$DIR":/workspace \
  -w /workspace \
  "$IMAGE" "${@:2}"
