#!/bin/bash
# Helper functions for CORSIKA; called from prepare_production.sh
#
# TMP changes
# TMP - VIEWCONE added
# TMP - fixed PHI
# TMP - CSCATTER increased

# preparation of CORSIKA containers
prepare_corsika_containers()
{
    DATA_DIR="$1"
    LOG_DIR="$2"
    mkdir -p "${DATA_DIR}"

    CONTAINER_EXTERNAL_DIR="-v \"${DATA_DIR}/CORSIKA:/workdir/external/data\" -v \"$LOG_DIR:/workdir/external/log\""
    CORSIKA_DATA_DIR="/workdir/external/data"
    if [[ $VTSSIMPIPE_CONTAINER == "docker" ]]; then
        COPY_COMMAND="docker run --rm $CONTAINER_EXTERNAL_DIR ${VTSSIMPIPE_CONTAINER_URL}${VTSSIMPIPE_CORSIKA_IMAGE}"
    elif [[ $VTSSIMPIPE_CONTAINER == "apptainer" ]]; then
        COPY_COMMAND="apptainer exec --cleanenv --no-mount bind-paths ${CONTAINER_EXTERNAL_DIR//-v/--bind} ${VTSSIMPIPE_CONTAINER_DIR}/${VTSSIMPIPE_CORSIKA_IMAGE/:/_}.sif"
    fi
    # copy corsika directory to data dir (as apptainers are readonly)
    echo "Copy CORSIKA files to ${DATA_DIR}/CORSIKA/tmp_corsika_run_files"
    mkdir -p "${DATA_DIR}/CORSIKA/tmp_corsika_run_files"
    COPY_COMMAND="$COPY_COMMAND bash -c \"cp /workdir/corsika-run/* /workdir/external/data/tmp_corsika_run_files\""
    eval "$COPY_COMMAND"
}


# core scatter area (in m)
get_corsika_core_scatter()
{
    ZENITH="$1"
    if [[ $ZENITH -lt 39 ]]; then
        echo "750.E2"
    elif [[ $ZENITH -lt 49 ]]; then
        echo "1000.E2"
    else
        echo "1500.E2"
    fi
}

# minimum energy (in GeV)
get_corsika_energy_min()
{
    ZENITH="$1"
    if [[ $ZENITH -lt 29 ]]; then
        echo "30."
    elif [[ $ZENITH -lt 54 ]]; then
        echo "50."
    else
        echo "100"
    fi
}

# CORSIKA input card
generate_corsika_input_card()
{
    OFILE="$1"
    N_SHOWER="$2"
    ZENITH="$3"
    ENERGY_MIN=$(get_corsika_energy_min "$ZENITH")
    CORE_SCATTER=$(get_corsika_core_scatter "$ZENITH")
    ATMOSPHERE="$4"
    CORSIKA_DATA_DIR="$5"

    echo "S1=\$((RANDOM % 900000000 - 1))" >> "$OFILE"
    echo "S2=\$((S1 + 2))" >> "$OFILE"
    echo "S3=\$((S2 + 2))" >> "$OFILE"
    echo "S4=\$((S3 + 2))" >> "$OFILE"

    {
        cat << EOF
# CORSIKACONFIG DATDIR $CORSIKA_DATA_DIR/tmp_corsika_run_files
# CORSIKACONFIG RUNNR  RUN_NUMBER
# CORSIKACONFIG EVTNR   1
# CORSIKACONFIG NSHOW $N_SHOWER
# CORSIKACONFIG CSCAT 10 $CORE_SCATTER 0.
# CORSIKACONFIG PRMPAR 1
# CORSIKACONFIG ERANGE $ENERGY_MIN 200.E3
# CORSIKACONFIG ESLOPE -1.5
# CORSIKACONFIG THETAP $ZENITH $ZENITH
# CORSIKACONFIG VIEWCONE 0. 3.5
# CORSIKACONFIG PHIP 0. 0.
# CORSIKACONFIG SEED S1 0 0
# CORSIKACONFIG SEED S2 0 0
# CORSIKACONFIG SEED S3 0 0
# CORSIKACONFIG SEED S4 0 0
# CORSIKACONFIG ATMOD 1
# CORSIKACONFIG MAGNET 25.2 40.88
# CORSIKACONFIG ARRANG 10.4
# CORSIKACONFIG ELMFLG F T
# CORSIKACONFIG RADNKG 200.E2
# CORSIKACONFIG FIXCHI 0.
# CORSIKACONFIG HADFLG 0 0 0 0 0 2
# CORSIKACONFIG QGSJET T 0
# CORSIKACONFIG QGSSIG T
# CORSIKACONFIG HILOW 100.
# CORSIKACONFIG ECUTS 0.30 0.05 0.02 0.02
# CORSIKACONFIG MUADDI F
# CORSIKACONFIG MUMULT T
# CORSIKACONFIG LONGI T 20. F F
# CORSIKACONFIG MAXPRT 50
# CORSIKACONFIG PAROUT F F
# CORSIKACONFIG ECTMAP 1.E5
# CORSIKACONFIG DEBUG F 6 F 1000000
# CORSIKACONFIG DIRECT $CORSIKA_DATA_DIR
# CORSIKACONFIG USER user
# CORSIKACONFIG ATMOSPHERE $ATMOSPHERE T
# CORSIKACONFIG OBSLEV 1270.E2
# CORSIKACONFIG TELESCOPE -23.7E2 37.6E2 0.E2 7.E2
# CORSIKACONFIG TELESCOPE -47.7E2 -44.1E2 4.4E2 7.E2
# CORSIKACONFIG TELESCOPE 60.1E2 -29.4E2 9.8E2 7.E2
# CORSIKACONFIG TELESCOPE 11.3E2 35.9E2 7.E2 7.E2
# CORSIKACONFIG TELESCOPE -8.61E2 -135.48E2 12.23E2 7.E2
# CORSIKACONFIG TELFIL $CORSIKA_DATA_DIR/DATRUN_NUMBER.telescope
# CORSIKACONFIG CERFIL 0
# CORSIKACONFIG CERSIZ 5.
# CORSIKACONFIG CWAVLG 250. 700.
# CORSIKACONFIG EXIT
EOF
} >> ${OFILE}

echo "input_file=$(dirname "$OFILE")/input_\${RUN_NUMBER}.dat" >> $OFILE

echo "rm -f \$input_file" >> $OFILE
echo "sed -n '/DATDIR/,/EXIT/{/DATDIR/!{/EXIT/!s/# CORSIKACONFIG //p}}' "\$0" > \$input_file" >> $OFILE
echo "sed -i \"s/RUN_NUMBER/\$RUN_NUMBER/\" \$input_file" >> $OFILE
echo "sed -i \"s/S1/\$S1/\" \$input_file" >> $OFILE
echo "sed -i \"s/S2/\$S2/\" \$input_file" >> $OFILE
echo "sed -i \"s/S3/\$S3/\" \$input_file" >> $OFILE
echo "sed -i \"s/S4/\$S4/\" \$input_file" >> $OFILE

}

generate_corsika_submission_script()
{
    FSCRIPT="$1"
    OUTPUT_DIR="$2"
    CONTAINER_EXTERNAL_DIR="$3"
    N_SHOWER="$4"
    ZENITH="$5"
    ATMOSPHERE="$6"
    CORSIKA_DATA_DIR="${7}"

    INPUT="/workdir/external/log/input_\${RUN_NUMBER}.dat"
    OUTPUT="/workdir/external/data/DAT\${RUN_NUMBER}"

    echo "#!/bin/bash" > "$FSCRIPT.sh"
    echo "RUN_NUMBER=\$1" >> "$FSCRIPT.sh"

    generate_corsika_input_card $FSCRIPT.sh "$N_SHOWER" "$ZENITH" "$ATMOSPHERE" "$CORSIKA_DATA_DIR"
    echo "rm -f ${OUTPUT_DIR}/DAT\${RUN_NUMBER}.log" >> "$FSCRIPT.sh"
    echo "rm -f ${OUTPUT_DIR}/DAT\${RUN_NUMBER}.telescope" >> "$FSCRIPT.sh"
    if [[ $VTSSIMPIPE_CONTAINER == "docker" ]]; then
        CORSIKA_EXE="docker run --rm $CONTAINER_EXTERNAL_DIR ${VTSSIMPIPE_CONTAINER_URL}${VTSSIMPIPE_CORSIKA_IMAGE}"
    elif [[ $VTSSIMPIPE_CONTAINER == "apptainer" ]]; then
        CORSIKA_EXE="apptainer exec --cleanenv --no-mount bind-paths ${CONTAINER_EXTERNAL_DIR//-v/--bind} ${VTSSIMPIPE_CONTAINER_DIR}/${VTSSIMPIPE_CORSIKA_IMAGE/:/_}.sif"
    fi
    CORSIKA_EXE="${CORSIKA_EXE} bash -c \"cd /workdir/external/data/tmp_corsika_run_files && /workdir/corsika-run/corsika77500Linux_QGSII_urqmd < $INPUT\""
    echo "$CORSIKA_EXE > ${OUTPUT_DIR}/DAT\${RUN_NUMBER}.log" >> "$FSCRIPT.sh"
    if [[ $VTSSIMPIPE_CONTAINER == "apptainer" ]]; then
        echo "apptainer inspect ${VTSSIMPIPE_CONTAINER_DIR}/${VTSSIMPIPE_CORSIKA_IMAGE/:/_}.sif >> ${OUTPUT_DIR}/DAT\${RUN_NUMBER}.log" >> "$FSCRIPT.sh"
    fi
    chmod u+x "$FSCRIPT.sh"
}
