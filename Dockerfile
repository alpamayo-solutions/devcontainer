FROM python:3.12-slim-bookworm

ARG NODE_MAJOR=22
ARG DEV_UID=1000
ARG DEV_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# `passwd` (groupadd/useradd) is not in python:3.12-slim by default. Install
# it together with the rest, then reserve UID/GID 1000 for the dev user
# before later packages (e.g. 1password-cli's 'onepassword-cli' user) can
# claim the same id.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg passwd \
      git openssh-server sudo \
      build-essential pkg-config \
      vim less jq tmux fish bash-completion \
      iproute2 iputils-ping dnsutils netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g ${DEV_GID} dev \
    && useradd -m -u ${DEV_UID} -g ${DEV_GID} -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 440 /etc/sudoers.d/dev

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
      | gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg \
    && echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/${ARCH} stable main" \
      > /etc/apt/sources.list.d/1password.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends 1password-cli \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/dev/.ssh /home/dev/.local/bin /home/dev/.npm-global \
             /home/dev/.cache /home/dev/.config /home/dev/work \
             /etc/host-keys /etc/ssh-host-keys \
    && chown -R dev:dev /home/dev \
    && chmod 700 /home/dev/.ssh

USER dev
RUN npm config set prefix /home/dev/.npm-global \
    && cat >> /home/dev/.bashrc <<'EOF'

# devcontainer additions
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONDONTWRITEBYTECODE=1

# Default to ~/work on login
[ -d "$HOME/work" ] && cd "$HOME/work"
EOF
USER root

COPY sshd_config /etc/ssh/sshd_config
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
