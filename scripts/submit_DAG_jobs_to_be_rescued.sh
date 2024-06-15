#!/bin/bash
# re-submit DAG jobs which failed in DESY environment
# use htc-submit.zeuthen.desy.de
# see https://dv-zeuthen.desy.de/services/batch/job_submission/ for details
#
# Submits all *.dag.rescue* files in the given directory
#
set -e

if [ $# -lt 1 ]
then
    echo "
    ./submit_DAG_jobs_to_be_rescued.sh <directory>

    Find all jobs to be rescued in a DAG directory and re-submit

    "
    exit
fi

FLIST=$(find ${1} -type f -name "*.dag.rescue*" -exec sh -c 'echo "$0" | sed "s/\.rescue.*//" ' {} \; | sort -u)

export _condor_SEC_TOKEN_DIRECTORY=$(mktemp -d)
condor_token_fetch -lifetime $((30*24*60*60)) -token dag

for F in ${FLIST}; do
    echo $F
    condor_submit_dag ${F}
done

exit $?
