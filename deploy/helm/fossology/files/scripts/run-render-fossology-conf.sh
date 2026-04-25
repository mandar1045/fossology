#
# SPDX-FileCopyrightText: © Fossology contributors
#
# SPDX-License-Identifier: FSFAP
#
#!/bin/sh
set -eu

set -- \
  --mode="${FOSSOLOGY_RENDER_MODE}" \
  --template="${FOSSOLOGY_RENDER_TEMPLATE}" \
  --output="${FOSSOLOGY_RENDER_OUTPUT}" \
  --namespace="${POD_NAMESPACE}" \
  --label-selector="${FOSSOLOGY_WORKER_LABEL_SELECTOR}" \
  --headless-service="${FOSSOLOGY_WORKER_HEADLESS_SERVICE}" \
  --worker-conf-dir="${FOSSOLOGY_WORKER_CONF_DIR}" \
  --max-agents-per-worker="${WORKER_MAX_AGENTS}" \
  --min-ready-workers="${FOSSOLOGY_MIN_READY_WORKERS}" \
  --scheduler-host="${MY_POD_IP}" \
  --poll-interval-seconds="${FOSSOLOGY_RENDER_POLL_INTERVAL_SECONDS}" \
  --timeout-seconds="${FOSSOLOGY_RENDER_TIMEOUT_SECONDS}"

if [ -n "${FOSSOLOGY_SIGNAL_COMMAND:-}" ]; then
  set -- "$@" --signal-command="${FOSSOLOGY_SIGNAL_COMMAND}"
fi

python3 /config-source/render_fossology_conf.py "$@"
chmod 644 "${FOSSOLOGY_RENDER_OUTPUT}"
