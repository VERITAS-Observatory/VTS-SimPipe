#!/bin/bash
# Generate CORSIKA input files and submission scripts
#
set -e

echo "Generate simulation input files and submission scripts."
echo

if [ $# -lt 3 ]; then
echo "./prepare_production.sh <simulation step> <config file> <input file template> <pull and prepare containers (TRUE/FALSE)

Allowed simulation steps: CORSIKA, GROPTICS, CARE

CORSIKA:
- template configuration file, see ./config/CORSIKA/config_template.dat
- input file template, see ./config/CORSIKA/input_template.dat
"
exit
fi

SIM_TYPE="$1"
CONFIG="$2"
INPUT_TEMPLATE="$3"
[[ "$4" ]] && PULL=$4 || PULL=FALSE

if [[ ! -e "$CONFIG" ]]; then
    echo "Configuration file $CONFIG does not exist."
    exit
fi
if [[ ! -e "$INPUT_TEMPLATE" ]]; then
    echo "Input file template $INPUT_TEMPLATE does not exist."
    exit
fi

echo "Simulation type: $SIM_TYPE"

# shellcheck source=/dev/null
. corsika.sh
# shellcheck source=/dev/null
. groptics.sh
# shellcheck source=/dev/null
. "$CONFIG"

# env variables
# shellcheck source=/dev/null
. "$(dirname "$0")"/../env_setup.sh
echo "VTSSIMPIPE_DATA_DIR: $VTSSIMPIPE_DATA_DIR"
echo "VTSSIMPIPE_LOG_DIR: $VTSSIMPIPE_LOG_DIR"
echo "VTSSIMPIPE_CONTAINER: $VTSSIMPIPE_CONTAINER"
echo "VTSSIMPIPE_CORSIKA_IMAGE: $VTSSIMPIPE_CORSIKA_IMAGE"

echo "Generating for $SIM_TYPE $N_RUNS input files and submission scripts (starting from run number $RUN_START)."
echo "Number of showers per run: $N_SHOWER"
echo "Atmosphere: $ATMOSPHERE"
echo "Zenith angle: $ZENITH deg"
if [[ $SIM_TYPE == "CORSIKA" ]]; then
    S1=65168195
    S1=$((RANDOM % 900000000 - 1))
    echo "First CORSIKA seed: $S1"
fi

# directories
DIRSUFF="ATM${ATMOSPHERE}/Zd${ZENITH}"
LOG_DIR="$VTSSIMPIPE_LOG_DIR"/"$DIRSUFF"/"$SIM_TYPE"
DATA_DIR="$VTSSIMPIPE_DATA_DIR"/"$DIRSUFF"
mkdir -p "${LOG_DIR}"
mkdir -p "${DATA_DIR}/${SIM_TYPE}"
echo "Log directory: $LOG_DIR"
echo "Data directory: $DATA_DIR"

# generate HT condor file
generate_htcondor_file()
{
    SUBSCRIPT=$(readlink -f "${1}")
    SUBFIL=${SUBSCRIPT}.condor
    rm -f "${SUBFIL}"

    cat > "${SUBFIL}" <<EOL
Executable = ${SUBSCRIPT}
Log = ${SUBSCRIPT}.\$(Cluster)_\$(Process).log
Output = ${SUBSCRIPT}.\$(Cluster)_\$(Process).output
Error = ${SUBSCRIPT}.\$(Cluster)_\$(Process).error
Log = ${SUBSCRIPT}.\$(Cluster)_\$(Process).log
request_memory = 2000M
getenv = True
max_materialize = 250
queue 1
EOL
# priority = 15
}

if [[ $SIM_TYPE == "CORSIKA" ]]; then
    prepare_corsika_containers "$DATA_DIR" "$LOG_DIR" \
        "$PULL" "$VTSSIMPIPE_CONTAINER" "$VTSSIMPIPE_CORSIKA_IMAGE"
elif [[ $SIM_TYPE == "GROPTICS" ]]; then
    prepare_groptics_containers "$DATA_DIR" "$LOG_DIR" "$ATMOSPHERE" \
        "$PULL" "$VTSSIMPIPE_CONTAINER" "$VTSSIMPIPE_GROPTICS_IMAGE"
elif [[ $SIM_TYPE == "CARE" ]]; then
    prepare_care_containers "$DATA_DIR" "$LOG_DIR" \
        "$PULL" "$VTSSIMPIPE_CONTAINER" "$VTSSIMPIPE_CARE_IMAGE"
else
    echo "Unknown simulation type $SIM_TYPE."
    exit
fi

for ID in $(seq 0 "$N_RUNS");
do
    run_number=$((ID + RUN_START))
    FSCRIPT="$LOG_DIR"/"run_${SIM_TYPE}_$run_number"
    INPUT="$LOG_DIR"/"input_$run_number.dat"
    OUTPUT_FILE="$DATA_DIR"/"DAT$run_number"

    if [[ $SIM_TYPE == "CORSIKA" ]]; then
        S4=$(generate_corsika_input_card \
           "$LOG_DIR" "$run_number" "$S1" \
           "$INPUT_TEMPLATE" "$N_SHOWER" "$ZENITH" "$ATMOSPHERE" \
           "$CORSIKA_DATA_DIR" "$VTSSIMPIPE_CONTAINER")
        S1=$((S4 + 2))

        generate_corsika_submission_script "$FSCRIPT" "$INPUT" "$OUTPUT_FILE" "$CONTAINER_EXTERNAL_DIR"
        generate_htcondor_file "$FSCRIPT.sh"
    elif [[ $SIM_TYPE == "GROPTICS" ]]; then
        generate_groptics_submission_script "$FSCRIPT" "$OUTPUT_FILE" \
            "$run_number" "$ATMOSPHERE" "$CONTAINER_EXTERNAL_DIR"
        generate_htcondor_file "$FSCRIPT.sh"
    fi
done

echo "End of job preparation for $SIM_TYPE ($LOG_DIR)."
