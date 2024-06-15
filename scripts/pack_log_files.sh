#!/bin/bash
# Pack log files in production directories into
# individual tar ball depending on the data level
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
Pack Simulation log files for each level.

./pack_log_files.sh <production directory>

Production directory is e.g., $VTSSIMPIPE_DATA_DIR/ATM62/Zd65/

"
exit
fi


PDIR="${1}"
DLIST="CORSIKA CARE_redHV CARE_std CLEANUP GROPTICS MERGEVBF_redHV MERGEVBF_std"

cd "${PDIR}"

for DIR in $DLIST; do
    echo $DIR
    if [ -e $DIR ]; then
        rm -f logs_${DIR}.tar
        find ${DIR} -type f -name "*.log" -exec bzip2 -v {} \;
        find ${DIR} -type f -name "*.log.bz2" -exec tar -rf logs_${DIR}.tar {} +
    fi
done
