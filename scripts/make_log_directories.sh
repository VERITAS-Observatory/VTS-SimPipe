#!/bin/bash
# Prepare log directories for HTCondor
#  (required to limit the number of output
#  files per directory for large productions)
set -e

if [ $# -lt 2 ]; then
echo "./make_log_directories.sh <log directory> <run number>

This is a HTCondor Pre-script called before starting a DAG job.

"
exit

fi
LOGDIR=${1}
RUN=${2}

DIR="CORSIKA CARE CORSIKA GROPTICS MERGEVBF CLEANUP"
for D in ${DIR}; do
    mkdir -p "${LOGDIR}/${D}/${RUN}"
done
