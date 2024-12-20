#!/bin/bash
#
# submit a list of scripts to HTCondor job submission system
#
# 1. submits all *.sh files in the given directory
# 2. searches for *.condor files for job submission details
#
# note: uses memory / CPU requests from first condor file.
#
set -e

if [ $# -lt 1 ]
then
    echo "
    ./submit_scripts_to_htcondor.sh <job directory> <submit/nosubmit>

    "
    exit
fi

JDIR="${1}"

SUBMITF=${JDIR}/submit.txt
rm -f "${SUBMITF}"
touch "${SUBMITF}"

echo "Writing HTCondor job submission file ${SUBMITF}"

mkdir -p "${JDIR}"/log
mkdir -p "${JDIR}"/output
mkdir -p "${JDIR}"/error

{
    echo "executable = \$(file)"
    echo "log = log/\$(file).log"
    echo "output = output/\$(file).output"
    echo "error = error/\$(file).error"
} >> "${SUBMITF}"

if ls "${JDIR}"/*.condor 1> /dev/null 2>&1; then
    # assume that all condor files have similar requests
    CONDORFILE=$(find "${JDIR}" -name "*.condor" | head -n 1)
    {
        grep -h request_memory "$CONDORFILE" || echo "request_memory = 2000M";
        echo "getenv = True";
        grep -h max_materialize "$CONDORFILE" || echo "max_materialize = 500";
        echo "priority = 150"
        echo "queue file matching files *.sh";
    } >> "${SUBMITF}"

    PDIR=$(pwd)
    if [ "${2}" = "submit" ]; then
        cd "${JDIR}"
        condor_submit submit.txt
        cd "${PDIR}"
    fi
else
    echo "Error: no condor files found in ${JDIR}"
fi
