# devcontainer

Minimal SSH-accessible Docker dev environment with Python 3.12 + Node 22.
Install extra packages dynamically; named volumes keep them across recreates.

Image: [`ghcr.io/alpamayo-solutions/devcontainer`](https://github.com/alpamayo-solutions/devcontainer/pkgs/container/devcontainer)
(multi-arch amd64/arm64). Apache 2.0.

## Usage

```bash
mkdir my-devcontainer && cd my-devcontainer
curl -fsSLO https://raw.githubusercontent.com/alpamayo-solutions/devcontainer/main/docker-compose.yml
curl -fsSL  https://raw.githubusercontent.com/alpamayo-solutions/devcontainer/main/.env.example -o .env

ssh-add -L > authorized_keys             # or: cat ~/.ssh/id_ed25519.pub > authorized_keys
$EDITOR .env                              # at minimum set WORK_DIR

docker compose up -d
ssh -p 2222 dev@localhost
```

That's it — just `docker-compose.yml` + `.env` + `authorized_keys`. No clone, no
helper scripts. The image embeds `sshd_config` and the entrypoint.

## What persists across recreates

| Mount                  | Type                | Contents                                     |
|------------------------|---------------------|----------------------------------------------|
| `~/work`               | bind → `WORK_DIR`   | your repos, editable from host and container |
| `~/.local`             | volume              | `pip install --user` packages                |
| `~/.npm-global`        | volume              | `npm install -g` packages                    |
| `~/.cache`, `~/.config`| volumes             | tool caches and configs                      |
| `~/.ssh`               | volume              | client-side state (`known_hosts`, user keys) |
| sshd host keys         | volume              | stable container fingerprint                 |

`docker compose down` keeps all volumes. Only `down -v` would wipe them.

For project-specific Python envs use `python -m venv .venv` inside `~/work` —
the venv lives in your bind-mounted workspace and survives anything.

## How `authorized_keys` is wired

Your file is bind-mounted **read-only** to `/etc/host-keys/authorized_keys`. The
entrypoint copies it on each start to `/home/dev/.ssh/authorized_keys` with
`dev:dev` ownership and mode `0600`. The `:ro` flag is kernel-enforced — the
container cannot modify the host file under any circumstance. Same pattern for
`~/.gitconfig`, so `git config --global` inside the container only edits the
in-container copy.

To rotate keys: edit `authorized_keys`, then `docker compose restart`.

## Local build

If you want to build the image yourself instead of pulling:

```bash
git clone https://github.com/alpamayo-solutions/devcontainer.git && cd devcontainer
docker build -t devcontainer:dev .
IMAGE=devcontainer:dev docker compose up -d
```

CI builds amd64+arm64 on every push to `main`; tagged releases (`vX.Y.Z`) get
matching semver tags on the package.
