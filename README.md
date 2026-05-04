# devcontainer

Minimal SSH-accessible Docker dev environment with Python and Node — install
extra packages dynamically and keep them across container recreates.

- **Image:** `python:3.12-slim-bookworm` + Node.js 22 + git + uv + common tools
- **SSH:** port 22 in the container, exposed on host port 2222 (configurable)
- **Auth:** pubkey only, no password, no root login
- **Persistence:** named volumes for `~/.local`, `~/.npm-global`, `~/.cache`,
  `~/.config`, `~/.ssh` client state, and the sshd host keys
- **Workspace:** a host directory bind-mounted at `~/work` for `git clone`s
  that you can edit from both your IDE on the host and inside the container

The image is published to
[`ghcr.io/alpamayo-solutions/devcontainer`](https://github.com/alpamayo-solutions/devcontainer/pkgs/container/devcontainer).

## Quick start

```bash
git clone https://github.com/alpamayo-solutions/devcontainer.git
cd devcontainer

# 1. Configure
cp .env.example .env
${EDITOR:-vim} .env                    # set WORK_DIR (and optionally SSH_PORT)

# 2. Provide your public key(s)
ssh-add -L > authorized_keys           # if you use ssh-agent (1Password, etc.)
# or:
cat ~/.ssh/id_ed25519.pub > authorized_keys

# 3. Start (pulls the published image by default)
docker compose up -d

# 4. Connect
ssh -p 2222 dev@localhost
```

For a fresh local build instead of the published image:

```bash
docker compose build
docker compose up -d
```

## Inside the container

```bash
# Python — install user-scoped tools that survive recreates
pip install --user black ruff httpx
# pip user installs land in ~/.local (persistent volume)

# Per-project venv inside ~/work (lives in your bind-mounted workspace)
cd ~/work/myrepo
python -m venv .venv && source .venv/bin/activate
pip install -e .

# Node — global CLIs persist via ~/.npm-global
npm install -g typescript pnpm

# uv (already installed) for fast Python envs
uv venv && source .venv/bin/activate
uv pip install fastapi
```

## What persists across `docker compose down` and recreates

| Path inside container | Volume / mount        | What lives here                             |
|-----------------------|-----------------------|---------------------------------------------|
| `~/work`              | bind to `WORK_DIR`    | your repos — edit from host or container    |
| `~/.local`            | volume `dev_local`    | `pip install --user` packages, uv installs  |
| `~/.npm-global`       | volume `dev_npm`      | `npm install -g` packages                   |
| `~/.cache`            | volume `dev_cache`    | pip / uv / npm caches                       |
| `~/.config`           | volume `dev_config`   | per-tool configs (fish, gh, etc.)           |
| `~/.ssh`              | volume `dev_ssh`      | client-side SSH state (`known_hosts`, keys) |
| `/etc/ssh-host-keys`  | volume `dev_host_keys`| sshd host keys → stable fingerprint         |
| `/home/dev/.gitconfig`| (synced from host)    | overwritten on each start, edits stay until next restart |

`docker compose down` keeps all volumes. Only `docker compose down -v` wipes
them (don't run that unless you mean it).

## How `authorized_keys` is wired (and why it can't trash your host file)

The host file (`AUTHORIZED_KEYS_FILE`, default `./authorized_keys`) is
**read-only** bind-mounted to `/etc/host-keys/authorized_keys` inside the
container. Three layers of safety:

1. **`:ro` is kernel-enforced.** The container can't write to the mount.
   No `chmod`, `chown`, or `rm` from inside touches the host file.
2. **It's mounted to a side path, not `~/.ssh/authorized_keys`.** The
   entrypoint copies the contents into `/home/dev/.ssh/authorized_keys` on
   each start, with `dev:dev` ownership and mode `0600`. sshd reads the copy.
3. **Bind mounts don't change source attributes.** Mounting is a VFS overlay;
   nothing the container does affects the host file's permissions.

To rotate keys: edit your host file (e.g. `ssh-add -L > authorized_keys`),
then `docker compose restart`.

The same pattern applies to `~/.gitconfig` — read-only mount, copied at start,
so `git config --global` inside the container only ever modifies the
in-container copy.

## Configuration

All settings live in `.env`. See [.env.example](.env.example) for defaults.

| Variable               | Default                                 | Purpose |
|------------------------|-----------------------------------------|---------|
| `IMAGE`                | `ghcr.io/alpamayo-solutions/devcontainer:latest` | Image to pull |
| `SSH_PORT`             | `2222`                                  | Host port → container :22 |
| `WORK_DIR`             | (you set this)                          | Host workspace bind-mounted at `~/work` |
| `AUTHORIZED_KEYS_FILE` | `./authorized_keys`                     | Pub keys allowed to log in |
| `GITCONFIG_FILE`       | `${HOME}/.gitconfig`                    | Host gitconfig to seed the container |
| `CONTAINER_NAME`       | `devcontainer`                          | Container/hostname |
| `TZ`                   | `Europe/Zurich`                         | Container timezone |
| `NODE_MAJOR`           | `22`                                    | Node major (build-time only) |
| `DEV_UID` / `DEV_GID`  | `1000` / `1000`                         | In-container user ids (build-time) |

## Multi-arch image

CI builds and pushes both `linux/amd64` and `linux/arm64`. Apple Silicon
(M-series Mac) and x86 hosts both pull the right manifest automatically.

Tags published:
- `latest` — tip of `main`
- `main` — same, branch-named
- `<semver>` — for git tags `vX.Y.Z` (`1.2.3`, `1.2`, `1`)
- `sha-<short>` — every commit

## License

Apache 2.0 — see [LICENSE](LICENSE).
