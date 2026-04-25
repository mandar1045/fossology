#
# SPDX-FileCopyrightText: © Fossology contributors
#
# SPDX-License-Identifier: FSFAP
#
#!/bin/bash
set -euo pipefail

export FOSSOLOGY_SCHEDULER_HOST="${MY_POD_IP}"
exec /fossology/docker-entrypoint.sh web
