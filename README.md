# claude-docker

Run [Claude Code](https://docs.claude.com/en/docs/claude-code) inside a locked-down Docker container.

- Edits only affect the project folder you mount — nothing else on your host.
- No SSH keys, no `~/.gitconfig`, no host env vars, no API key leak in.
- Your subscription login is persisted in a dedicated host folder, so you only `/login` once.

## Why

Running an autonomous coding agent directly on your machine gives it access to every credential in your shell env, your SSH keys, your AWS config, every repo on disk, etc. This setup confines Claude Code to a single directory and a single auth folder.

## Requirements

- Docker (Desktop on macOS/Windows, or Engine on Linux)
- A Claude subscription (Pro / Max) — no API key needed

## Quick start

```bash
git clone <this-repo> claude-docker
cd claude-docker
chmod +x run.sh

# Point at any project directory you want Claude to work on:
./run.sh /path/to/your/project
```

First time only: inside Claude, run `/login` and complete the subscription flow in your browser. The session is saved to `~/.claude-docker-auth` on your host and reused automatically next time.

If you omit the path, the current directory is used:

```bash
cd /path/to/your/project
/path/to/claude-docker/run.sh
```

## What gets mounted into the container

| Host path | Container path | Purpose |
|---|---|---|
| `<your project>` | `/workspace` | Read/write. Edits land on your host. |
| `~/.claude-docker-auth` | `/home/claude/.claude` | Persistent subscription login + Claude Code state. |

That's it. No other host paths are visible inside the container.

## Sandbox hardening applied

- Non-root user matching your host UID/GID (files you create are owned by you)
- `--read-only` root filesystem; only `/workspace` and `/tmp` (tmpfs) are writable
- `--cap-drop ALL` and `--security-opt no-new-privileges`
- `--env-file /dev/null` — no host environment variables forwarded
- Memory and PID limits

## Configuration

Environment variables the launcher understands:

| Var | Default | Meaning |
|---|---|---|
| `CLAUDE_DOCKER_AUTH_DIR` | `~/.claude-docker-auth` | Where subscription tokens are stored on the host |

### Using docker compose instead

```bash
# In the claude-docker directory:
WORKSPACE=/path/to/your/project docker compose run --rm claude
```

Compose reads the same `CLAUDE_DOCKER_AUTH_DIR` variable if you want to override the auth location.

## Where are my credentials?

On your host: `~/.claude-docker-auth/`

Inside that folder after `/login`:

- `.credentials.json` — OAuth tokens (sensitive; chmod 600)
- `settings.json`, `projects/`, `todos/` — Claude Code local state

To log out / wipe the saved session:

```bash
rm -rf ~/.claude-docker-auth
```

## Updating Claude Code

Rebuild the image to pick up a newer version:

```bash
docker rmi claude-code:local
./run.sh /path/to/your/project   # rebuilds on next run
```

To pin a specific version, edit the `CLAUDE_VERSION` arg in `Dockerfile` (defaults to `latest`).

## Troubleshooting

**"GID already exists" during build** — on macOS, your group (`staff`, GID 20) may collide with a base-image group. The Dockerfile already handles this by reusing the existing GID.

**Can't run `git push` / SSH from inside the container** — by design. SSH keys and git credentials are not mounted. Run git operations from your host terminal.

**`/login` opens a URL but nothing happens** — copy the URL from the terminal into your host browser manually; the container has no browser.

## Security notes

This is a reasonable sandbox, not a perfect one. It does not protect against:

- Malicious code inside `/workspace` (you still chose to run the agent on that code)
- Container escapes via kernel bugs (keep Docker updated)
- Network-based exfiltration — the container has full outbound network. If you want to restrict it, add `--network none` to `run.sh`, but note Claude Code needs network to talk to Anthropic.

## License

MIT
