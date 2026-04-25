#
# SPDX-FileCopyrightText: © Fossology contributors
#
# SPDX-License-Identifier: FSFAP
#
#!/bin/sh
set -eu

until pg_isready \
  -h "${FOSSOLOGY_DB_HOST}" \
  -U "${FOSSOLOGY_DB_USER}" \
  -d "${FOSSOLOGY_DB_NAME}"; do
  echo "Waiting for database..."
  sleep 3
done

echo "Database is ready!"
