# claude-docker

Run [Claude Code](https://docs.claude.com/en/docs/claude-code) inside a locked-down Docker container.

- Edits only affect the project folder you mount.
- No SSH keys, `~/.gitconfig`, host env vars, or API keys leak in.
- Subscription login is persisted on the host — `/login` once.

## Requirements

- Docker
- A Claude subscription (Pro / Max)

## Quick start

```bash
git clone <this-repo> claude-docker
cd claude-docker
cp .env.example .env          # optional: enable Go/Python/Rust, pin version
chmod +x run.sh

./run.sh /path/to/your/project
```

First run: inside Claude, run `/login`. The session is saved to `~/.claude-docker-auth` and reused next time.

Omit the path to use the current directory:

```bash
cd /path/to/project && /path/to/claude-docker/run.sh
```

## Configuration (`.env`)

| Var | Default | Meaning |
|---|---|---|
| `CLAUDE_DOCKER_AUTH_DIR` | `~/.claude-docker-auth` | Host path for persistent login |
| `WORKSPACE` | `./workspace` | Project path (docker compose only) |
| `CLAUDE_VERSION` | `latest` | Claude Code npm version |
| `WITH_GO` | `0` | Install latest Go |
| `WITH_PYTHON` | `0` | Install Python 3 + pip + venv |
| `WITH_RUST` | `0` | Install Rust (rustup, minimal) |
| `WITH_BUILD_ESSENTIAL` | `0` | Install C toolchain |
| `EXTRA_APT_PACKAGES` | — | Space-separated extra apt packages |

Changing toggles automatically triggers a rebuild (the image tag includes a hash of them).

## Mounts

| Host | Container | Purpose |
|---|---|---|
| `<project>` | `/workspace` | Read/write project files |
| `$CLAUDE_DOCKER_AUTH_DIR` | `/home/claude/.claude` | Login + Claude state |
| `$CLAUDE_DOCKER_AUTH_DIR/.config` | `/home/claude/.config/claude` | Extra Claude state |

Nothing else from the host is visible inside the container.

## Sandbox

- Non-root user matching host UID/GID
- `--read-only` root FS; only `/workspace`, `/tmp`, and a few caches (tmpfs) are writable
- `--cap-drop ALL`, `--security-opt no-new-privileges`
- `--env-file /dev/null` — no host env forwarded
- Memory (4g) and PID (512) limits

## docker compose

```bash
docker compose run --rm claude
```

Uses the same `.env`.

## MCP servers

```bash
# inside the container
claude mcp add <name> -- npx -y @some/mcp-server
```

Config is stored in the persisted auth dir. HTTP/SSE and stdio (`npx`/`uvx`) servers work out of the box. For pre-installed servers, add a `RUN` line to the `Dockerfile`.

## Logout / wipe

```bash
rm -rf ~/.claude-docker-auth
```

## Troubleshooting

- **`/login` browser doesn't open** — copy the URL into your host browser; the container has none.
- **Can't `git push`** — by design, SSH keys aren't mounted. Push from the host.
- **GID collision on build** — handled automatically (existing GID reused).

## Security notes

Reasonable sandbox, not perfect. It does not protect against malicious code in `/workspace`, container escapes, or network exfiltration (outbound network is open — Claude needs it). Add `--network none` if you want to cut that.

## License

MIT
