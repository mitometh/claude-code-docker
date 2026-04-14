#!/usr/bin/env bash
# Launcher: runs Claude Code in a sandboxed container.
# Mounts the target directory as /workspace and a persistent auth dir so
# subscription login survives between runs. No host SSH keys, gitconfig,
# or env vars leak in.
set -euo pipefail

# ---------- Constants ----------
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly IMAGE_BASE="claude-code:local"
readonly MEM_LIMIT="4g"
readonly PIDS_LIMIT="512"
readonly TMP_SIZE="256m"
readonly NPM_SIZE="256m"
readonly CACHE_SIZE="256m"
readonly GO_TMP_SIZE="512m"

# ---------- Load .env (optional) ----------
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a; . "$SCRIPT_DIR/.env"; set +a
fi

# ---------- Resolved config ----------
CLAUDE_VERSION="${CLAUDE_VERSION:-latest}"
WITH_GO="${WITH_GO:-0}"
WITH_PYTHON="${WITH_PYTHON:-0}"
WITH_RUST="${WITH_RUST:-0}"
WITH_BUILD_ESSENTIAL="${WITH_BUILD_ESSENTIAL:-0}"
EXTRA_APT_PACKAGES="${EXTRA_APT_PACKAGES:-}"
AUTH_DIR="${CLAUDE_DOCKER_AUTH_DIR:-$HOME/.claude-docker-auth}"

TARGET_DIR="${1:-$PWD}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Tag image by toggle hash so changing toggles auto-rebuilds.
toggle_hash=$(printf '%s|%s|%s|%s|%s|%s' \
  "$WITH_GO" "$WITH_PYTHON" "$WITH_RUST" \
  "$WITH_BUILD_ESSENTIAL" "$EXTRA_APT_PACKAGES" "$CLAUDE_VERSION" \
  | shasum | cut -c1-8)
IMAGE="${IMAGE_BASE}-${toggle_hash}"

# ---------- Prepare host auth dir ----------
mkdir -p "$AUTH_DIR" "$AUTH_DIR/.config"
chmod 700 "$AUTH_DIR"

# ---------- Build if needed ----------
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE..."
  docker build \
    --build-arg USER_UID="$(id -u)" \
    --build-arg USER_GID="$(id -g)" \
    --build-arg CLAUDE_VERSION="$CLAUDE_VERSION" \
    --build-arg WITH_GO="$WITH_GO" \
    --build-arg WITH_PYTHON="$WITH_PYTHON" \
    --build-arg WITH_RUST="$WITH_RUST" \
    --build-arg WITH_BUILD_ESSENTIAL="$WITH_BUILD_ESSENTIAL" \
    --build-arg EXTRA_APT_PACKAGES="$EXTRA_APT_PACKAGES" \
    -t "$IMAGE" \
    "$SCRIPT_DIR"
fi

# ---------- Run ----------
exec docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --read-only \
  --tmpfs "/tmp:size=${TMP_SIZE}" \
  --tmpfs "/home/claude/.npm:size=${NPM_SIZE}" \
  --tmpfs "/home/claude/.cache:size=${CACHE_SIZE}" \
  --tmpfs "/home/claude/go:size=${GO_TMP_SIZE}" \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  --pids-limit "$PIDS_LIMIT" \
  --memory "$MEM_LIMIT" \
  --env-file /dev/null \
  -e TERM=xterm-256color \
  -e CLAUDE_CONFIG_DIR=/home/claude/.claude \
  -v "$AUTH_DIR":/home/claude/.claude \
  -v "$AUTH_DIR/.config":/home/claude/.config/claude \
  -v "$TARGET_DIR":/workspace \
  -w /workspace \
  "$IMAGE" "${@:2}"
