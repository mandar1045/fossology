#
# SPDX-FileCopyrightText: © Fossology contributors
#
# SPDX-License-Identifier: FSFAP
#
#!/bin/bash
set -euo pipefail

echo "[scheduler] Setting up SSH client..."
mkdir -p /root/.ssh /home/fossy/.ssh
cp /run/secrets/ssh-private/id_ed25519 /root/.ssh/id_ed25519
cp /run/secrets/ssh-private/id_ed25519 /home/fossy/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519 /home/fossy/.ssh/id_ed25519
printf 'Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n  IdentityFile /root/.ssh/id_ed25519\n' > /root/.ssh/config
printf 'Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n  IdentityFile /home/fossy/.ssh/id_ed25519\n' > /home/fossy/.ssh/config
chmod 600 /root/.ssh/config /home/fossy/.ssh/config
chown -R fossy:fossy /home/fossy/.ssh

echo "[scheduler] Scheduler will bind to pod IP: ${MY_POD_IP}"
chmod 644 /usr/local/etc/fossology/fossology.conf || true
echo "[scheduler] Active worker hosts:"
sed -n '/^\[HOSTS\]/,/^\[REPOSITORY\]/p' /usr/local/etc/fossology/fossology.conf

export FOSSOLOGY_SCHEDULER_HOST="${MY_POD_IP}"
exec /fossology/docker-entrypoint.sh scheduler
