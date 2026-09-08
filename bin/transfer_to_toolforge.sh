#!/usr/bin/env bash
set -e

# Configurazione
OLD_HOST="c.ferdi.cc"
OLD_USER="deploy"
OLD_APP_DIR="/home/deploy/apps/wikilovesmonuments/current"
TOOL_NAME="${1:-wlm-italy}"
DUMP_FILE="wlm_data_$(date +%Y%m%d_%H%M%S).json.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Sincronizzazione task ed esportazione dati dal vecchio server (${OLD_HOST}) ==="
scp "${SCRIPT_DIR}/../lib/tasks/db_transfer.rake" "${OLD_USER}@${OLD_HOST}:${OLD_APP_DIR}/lib/tasks/db_transfer.rake"
ssh "${OLD_USER}@${OLD_HOST}" "bash -l -c 'cd ${OLD_APP_DIR} && RAILS_ENV=production bundle exec rake \"db:export_data[/tmp/${DUMP_FILE}]\"'"

echo "=== 2. Download del dump in locale ==="
scp "${OLD_USER}@${OLD_HOST}:/tmp/${DUMP_FILE}" "./${DUMP_FILE}"
ssh "${OLD_USER}@${OLD_HOST}" "rm -f /tmp/${DUMP_FILE}"

echo "=== 3. Upload del dump su Toolforge Bastion ==="
scp "./${DUMP_FILE}" "login.toolforge.org:/data/project/${TOOL_NAME}/${DUMP_FILE}"

echo ""
echo "=== 4. Istruzioni per importare i dati su Toolforge ==="
echo "Collegati su Toolforge bastion ed esegui:"
echo "  ssh login.toolforge.org"
echo "  become ${TOOL_NAME}"
echo "  toolforge jobs run import-data-job \\"
echo "    --image tool-${TOOL_NAME}/tool-${TOOL_NAME}:latest \\"
echo "    --command \"bundle exec rake 'db:import_data[/data/project/${TOOL_NAME}/${DUMP_FILE}]'\" \\"
echo "    --mount all \\"
echo "    --wait"
echo ""
echo "  toolforge jobs logs import-data-job"
echo "  toolforge jobs delete import-data-job"
echo "  rm -f /data/project/${TOOL_NAME}/${DUMP_FILE}"
