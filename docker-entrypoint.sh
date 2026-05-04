#!/bin/bash
set -e

# Generate SSH host keys once into the persistent volume so the container
# fingerprint is stable across recreates.
if [ ! -f /etc/ssh-host-keys/ssh_host_ed25519_key ]; then
    echo "[entrypoint] generating SSH host keys"
    ssh-keygen -q -t ed25519 -f /etc/ssh-host-keys/ssh_host_ed25519_key -N ''
    ssh-keygen -q -t rsa -b 4096 -f /etc/ssh-host-keys/ssh_host_rsa_key -N ''
    ssh-keygen -q -t ecdsa -b 521 -f /etc/ssh-host-keys/ssh_host_ecdsa_key -N ''
fi
chmod 600 /etc/ssh-host-keys/*_key 2>/dev/null || true
chmod 644 /etc/ssh-host-keys/*.pub  2>/dev/null || true

# Re-create dirs in case named volumes mounted empty over them.
mkdir -p /home/dev/.ssh /home/dev/.local/bin /home/dev/.npm-global \
         /home/dev/.cache /home/dev/.config /home/dev/work
chown -R dev:dev /home/dev/.ssh /home/dev/.local /home/dev/.npm-global \
                  /home/dev/.cache /home/dev/.config 2>/dev/null || true
chmod 700 /home/dev/.ssh

# Sync authorized_keys from the read-only host bind mount on every start.
# Source: /etc/host-keys/authorized_keys (mounted :ro from host, kernel-enforced).
# We copy into /home/dev/.ssh/ with dev:dev / 0600 so sshd's StrictModes is happy.
if [ -f /etc/host-keys/authorized_keys ]; then
    install -m 600 -o dev -g dev \
        /etc/host-keys/authorized_keys /home/dev/.ssh/authorized_keys
    KEY_COUNT=$(grep -cv '^[[:space:]]*\(#\|$\)' /home/dev/.ssh/authorized_keys || true)
    echo "[entrypoint] synced authorized_keys from host (${KEY_COUNT} key(s))"
else
    echo "[entrypoint] WARNING: /etc/host-keys/authorized_keys not present — SSH login will fail"
fi

# Sync optional .gitconfig from host (read-only mount). Copy lets git config --global
# write inside the container without ever touching the host file.
if [ -f /etc/host-keys/gitconfig ]; then
    install -m 644 -o dev -g dev /etc/host-keys/gitconfig /home/dev/.gitconfig
    echo "[entrypoint] synced .gitconfig from host"
fi

# Make sure npm prefix is set (volume can shadow .npmrc).
sudo -u dev bash -c '
    npm config get prefix 2>/dev/null | grep -q npm-global \
        || npm config set prefix /home/dev/.npm-global
'

exec "$@"
