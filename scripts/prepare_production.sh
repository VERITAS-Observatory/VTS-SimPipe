#!/bin/bash
# Generate simulation submission scripts
#
set -e

echo "Generate simulation submission scripts."
echo

if [ $# -lt 2 ]; then
echo "./prepare_production.sh <simulation step> <config file>

Allowed simulation steps: CORSIKA, GROPTICS, CARE, MERGEVBF, CLEANUP

CORSIKA:
- template configuration file, see ./config/config_ATM61_template.dat
"
exit
fi

SIM_TYPE="$1"
CONFIG="$2"

if [[ ! -e "$CONFIG" ]]; then
    echo "Configuration file $CONFIG does not exist."
    exit
fi

echo "Simulation type: $SIM_TYPE"

# shellcheck source=/dev/null
. corsika.sh
# shellcheck source=/dev/null
. groptics.sh
# shellcheck source=/dev/null
. care.sh
# shellcheck source=/dev/null
. mergevbf.sh
# shellcheck source=/dev/null
. cleanup.sh
# shellcheck source=/dev/null
. "$CONFIG"

# env variables
# shellcheck source=/dev/null
. "$(dirname "$0")"/../env_setup.sh
echo "VTSSIMPIPE_DATA_DIR: $VTSSIMPIPE_DATA_DIR"
echo "VTSSIMPIPE_LOG_DIR: $VTSSIMPIPE_LOG_DIR"
echo "VTSSIMPIPE_CONTAINER: $VTSSIMPIPE_CONTAINER"
echo "VTSSIMPIPE_CORSIKA_IMAGE: $VTSSIMPIPE_CORSIKA_IMAGE"
echo "VTSSIMPIPE_GROPTICS_IMAGE: $VTSSIMPIPE_GROPTICS_IMAGE"
echo "VTSSIMPIPE_CARE_IMAGE: $VTSSIMPIPE_CARE_IMAGE"

echo "Generating for $SIM_TYPE $N_RUNS submission scripts (starting from run number $RUN_START)."
echo "Number of showers per run: $N_SHOWER"
echo "Atmosphere: $ATMOSPHERE"
echo "Zenith angle: $ZENITH deg"
echo "Wobble angle: $WOBBLE_LIST deg"
echo "NSB rate: $NSB_LIST MHz"

# directories
DIRSUFF="ATM${ATMOSPHERE}/Zd${ZENITH}"
LOG_DIR="$VTSSIMPIPE_LOG_DIR"/"$DIRSUFF"/"$SIM_TYPE"
DATA_DIR="$VTSSIMPIPE_DATA_DIR"/"$DIRSUFF"
mkdir -p "${LOG_DIR}"
echo "Log directory: $LOG_DIR"

# generate HT condor file
generate_htcondor_file()
{
    SUBSCRIPT=$(readlink -f "${1}")
    SUBFIL=${SUBSCRIPT}.condor
    rm -f "${SUBFIL}"

    if [[ ${2} == "NO_RUN_NUMBER" ]]; then
        cat > "${SUBFIL}" <<EOL
Executable = ${SUBSCRIPT}
Log = $(dirname ${SUBSCRIPT})/$(basename ${SUBSCRIPT})_\$(Cluster)_\$(Process).log
Output = $(dirname ${SUBSCRIPT})/$(basename ${SUBSCRIPT})_\$(Cluster)_\$(Process).output
Error = $(dirname ${SUBSCRIPT})/$(basename ${SUBSCRIPT})_\$(Cluster)_\$(Process).error
request_memory = 20000M
getenv = True
max_materialize = 2000
queue 1
EOL
    else
        cat > "${SUBFIL}" <<EOL
Executable = ${SUBSCRIPT}
Arguments = \$(run_number) \$(wobble_offset) \$(nsb_level)
Log = $(dirname ${SUBSCRIPT})/\$(run_number)/$(basename ${SUBSCRIPT})_\$(Cluster)_\$(Process).log
Output = $(dirname ${SUBSCRIPT})/\$(run_number)/$(basename ${SUBSCRIPT})_\$(Cluster)_\$(Process).output
Error = $(dirname ${SUBSCRIPT})/\$(run_number)/$(basename ${SUBSCRIPT})_\$(Cluster)_\$(Process).error
request_memory = 8000M
getenv = True
max_materialize = 2000
queue 1
EOL
    fi
}

# return string with CARE configs
# in most cases, this is "std", "redHV", or "std redHV"
get_care_configs()
{
    c_config=""
    if [ -n "${CARE_CONFIG_std}" ]; then
        c_config="$c_config std "
    fi
    if [ -n "${CARE_CONFIG_redHV}" ]; then
        c_config="$c_config redHV "
    fi
    echo "$c_config"
}

if [[ $SIM_TYPE == "CORSIKA" ]]; then
    prepare_corsika_containers "$DATA_DIR" "$LOG_DIR"
elif [[ $SIM_TYPE == "GROPTICS" ]]; then
    for WOBBLE in ${WOBBLE_LIST}; do
        prepare_groptics_containers "$DATA_DIR" "$ATMOSPHERE" "$WOBBLE"
    done
elif [[ $SIM_TYPE == "CARE" ]]; then
    for config in $(get_care_configs); do
        prepare_care_containers "$DATA_DIR" "$config"
    done
elif [[ $SIM_TYPE == "MERGEVBF" ]]; then
    echo "(nothing to prepare for mergevbf)"
elif [[ $SIM_TYPE == "CLEANUP" ]]; then
    echo "(nothing to prepare for cleanup)"
else
    echo "Unknown simulation type $SIM_TYPE."
    exit
fi

FSCRIPT="$LOG_DIR"/"run_${SIM_TYPE}"
OUTPUT_DIR="${DATA_DIR}/${SIM_TYPE}"
if [[ $SIM_TYPE == "CORSIKA" ]]; then
    generate_corsika_submission_script \
        "$FSCRIPT" "$OUTPUT_DIR" "$CONTAINER_EXTERNAL_DIR" \
        "$N_SHOWER" "$ZENITH" "$ATMOSPHERE" "$CORSIKA_DATA_DIR" "$VTSSIMPIPE_CONTAINER"
    generate_htcondor_file "$FSCRIPT.sh"
elif [[ $SIM_TYPE == "GROPTICS" ]]; then
    generate_groptics_submission_script "${FSCRIPT}" "$OUTPUT_DIR"
    generate_htcondor_file "${FSCRIPT}.sh"
elif [[ $SIM_TYPE == "CLEANUP" ]]; then
    generate_cleanup_submission_script "${FSCRIPT}" "$OUTPUT_DIR"
    generate_htcondor_file "${FSCRIPT}.sh"
elif [[ $SIM_TYPE == "CARE" ]]; then
    for config in $(get_care_configs); do
        care_config="CARE_CONFIG_$config"
        generate_care_submission_script "${FSCRIPT}_${config}" "$OUTPUT_DIR" \
            "${!care_config}" "${config}"
        generate_htcondor_file "${FSCRIPT}_${config}.sh"
    done
fi

if [[ $SIM_TYPE == "MERGEVBF" ]]; then
    for WOBBLE in ${WOBBLE_LIST}; do
        for config in $(get_care_configs); do
            care_nsb_list="NSB_LIST_$config"
            for NSB in ${!care_nsb_list}; do
                generate_mergevbf_submission_script "${FSCRIPT}_${config}_${WOBBLE}_${NSB}" "$OUTPUT_FILE" \
                    "${WOBBLE}" "${NSB}" "${config}"
                for sub_script in "${FSCRIPT}_${config}_${WOBBLE}_${NSB}"*.sh; do
                    generate_htcondor_file "$sub_script" NO_RUN_NUMBER
                done
            done
        done
    done
fi

echo "End of job preparation for $SIM_TYPE ($LOG_DIR)."
