#
# SPDX-FileCopyrightText: © Fossology contributors
#
# SPDX-License-Identifier: FSFAP
#
#!/bin/bash
set -euo pipefail

/bin/sh /config-source/wait-for-db.sh

cat <<EOF >/usr/local/etc/fossology/Db.conf
dbname=${FOSSOLOGY_DB_NAME};
host=${FOSSOLOGY_DB_HOST};
user=${FOSSOLOGY_DB_USER};
password=${FOSSOLOGY_DB_PASSWORD};
EOF

export PGHOST="${FOSSOLOGY_DB_HOST}"
export PGPASSWORD="${FOSSOLOGY_DB_PASSWORD}"

/usr/local/lib/fossology/fo-postinstall --common --database --licenseref
