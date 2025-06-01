#!/bin/bash
# Helper functions for mergevbf; called from prepare_production.sh

get_merge_file_name()
{
    WOBBLE="$1"
    NSB="$2"

    # gamma_V6_CARE_std_Atmosphere61_zen20deg_1.0wob_160MHz_1.vbf.zst
    FNAME="gamma_V6_CARE"
    if [[ $OBS_MODE == *"redHV"* ]]; then
        FNAME="${FNAME}_redHV"
    else
        FNAME="${FNAME}_std"
    fi
    FNAME="${FNAME}_Atmosphere${ATMOSPHERE}"
    FNAME="${FNAME}_zen${ZENITH}deg"
    FNAME="${FNAME}_${WOBBLE}wob"
    FNAME="${FNAME}_${NSB}MHz_"
    echo "$FNAME"
}


#####################################################################
# generate mergevbf input files and submission scripts
#
# /workdir/external/log:     directory for run scripts and pilot files
# /workdir/external/care     :directory with CARE (input) files
#
generate_mergevbf_submission_script()
{
    MERGEVBFFSCRIPT="$1"
    LOG_DIR=$(dirname "$MERGEVBFFSCRIPT")
    OUTPUT_FILE="$2"
    rm -f "$OUTPUT_FILE.mergevbf.log"
    WOBBLE="$3"
    NSB="$4"
    OBS_MODE="$5"

    # mount directories
    CARE_DATA_DIR="${DATA_DIR}/CARE_${OBS_MODE}/W${WOBBLE}/NSB${NSB}"
    MERGEVBF_DATA_DIR="${DATA_DIR}/MERGEVBF_${OBS_MODE}"
    mkdir -p "$MERGEVBF_DATA_DIR"
    CONTAINER_EXTERNAL_DIR="-v \"${MERGEVBF_DATA_DIR}:/workdir/external/mergevbf\""
    CONTAINER_EXTERNAL_DIR="$CONTAINER_EXTERNAL_DIR -v \"${CARE_DATA_DIR}:/workdir/external/care\""
    CONTAINER_EXTERNAL_DIR="$CONTAINER_EXTERNAL_DIR -v \"$LOG_DIR:/workdir/external/log/\""

    if [[ $VTSSIMPIPE_CONTAINER == "docker" ]]; then
        MERGE_EXE="docker run --rm $CONTAINER_EXTERNAL_DIR ${VTSSIMPIPE_CONTAINER_URL}${VTSSIMPIPE_MERGEVBF_IMAGE}"
    elif [[ $VTSSIMPIPE_CONTAINER == "apptainer" ]]; then
        MERGE_EXE="apptainer exec --cleanenv ${CONTAINER_EXTERNAL_DIR//-v/--bind} ${VTSSIMPIPE_CONTAINER_DIR}/${VTSSIMPIPE_MERGEVBF_IMAGE/:/_}.sif"
    fi

    batch_size=251
    vbf_id="0"
    MERGEDFILE=$(get_merge_file_name "$WOBBLE" "$NSB" "$vbf_id")
    TMP_FL_LIST="$MERGEVBF_DATA_DIR"/tmp_file_list_${WOBBLE}_${NSB}.dat
    rm -f "$TMP_FL_LIST"
    TMP_FL_SPLIT_LIST="$MERGEVBF_DATA_DIR/tmp_file_list_split_${WOBBLE}_${NSB}_"
    rm -f "${TMP_FL_SPLIT_LIST:?}*"
    rm -f "${MERGEVBFFSCRIPT}_${vbf_id}.sh"

    # all below is running in the submitted script
    (
        echo "#!/bin/bash"
        echo "set -e"
        echo
        echo "MERGEDFILE=$MERGEDFILE"
        echo
        echo "find \"$CARE_DATA_DIR\" -type f -name \"*.vbf\" -exec basename {} \; | sed 's|^|/workdir/external/care/|' | sort -n > \"$TMP_FL_LIST\""
        echo
        echo "while read -r file; do"
        echo "   ${MERGE_EXE} bash -c \"/workdir/VBF/bin/vbfReindex "\$file"\""
        echo "done < \"$TMP_FL_LIST\""
        echo
        echo "split -d -l $batch_size \"$TMP_FL_LIST\" \"$TMP_FL_SPLIT_LIST\""
        echo "for flist in \"$TMP_FL_SPLIT_LIST\"*; do"
        echo "   RUNNUMBER=\$(head -n 1 \"\$flist\" | awk -F '[^0-9]+' '{print \$2}')"
        echo "   echo \"\$RUNNUMBER\""
        echo "   if [[ -e \"${MERGEVBF_DATA_DIR}/${MERGEDFILE}\${RUNNUMBER}.vbf.zst\" ]] && [[ ! -e \"${MERGEVBF_DATA_DIR}/${MERGEDFILE}\${RUNNUMBER}.vbf\" ]]; then"
        echo "      echo \" Found ${MERGEVBF_DATA_DIR}/${MERGEDFILE}\${RUNNUMBER}.vbf.zst; skipping job\""
        echo "      continue"
        echo "   fi"
        echo "   MERGEVBF=\"./bin/mergeVBF /workdir/external/mergevbf/\$(basename \"\$flist\")  /workdir/external/mergevbf/\${MERGEDFILE}\${RUNNUMBER}.vbf \${RUNNUMBER}\""
        echo "   REINDEX=\"/workdir/VBF/bin/vbfReindex /workdir/external/mergevbf/${MERGEDFILE}\${RUNNUMBER}.vbf\""
        echo "   ZSTD_VBF=\"zstd -f /workdir/external/mergevbf/${MERGEDFILE}\${RUNNUMBER}.vbf\""
        echo "   echo \"LOG FILE ${MERGEVBF_DATA_DIR}/${MERGEDFILE}\${RUNNUMBER}.log\""
        echo "   ${MERGE_EXE} bash -c \"cd /workdir/EventDisplay_v4 && \${MERGEVBF} && \${REINDEX} && \${ZSTD_VBF}\" > ${MERGEVBF_DATA_DIR}/${MERGEDFILE}\"\${RUNNUMBER}\".log 2>&1"
        echo
        echo "   [ -e \"${MERGEVBF_DATA_DIR}/${MERGEDFILE}\${RUNNUMBER}.vbf.zst\" ] && rm -f \"${MERGEVBF_DATA_DIR}/${MERGEDFILE}\${RUNNUMBER}.vbf\""
        echo "done"
    ) >> "${MERGEVBFFSCRIPT}_${vbf_id}.sh"
    chmod u+x "${MERGEVBFFSCRIPT}_${vbf_id}.sh"
}
