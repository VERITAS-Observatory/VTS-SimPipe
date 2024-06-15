#!/bin/bash
# Helper functions for clean of files

#####################################################################
# preparation of GrOptics containers
#
# Unfortunately quite fine tuned due to directory requirements of
# corsikaIOreader and grOptics:
#
# /workdir/external/corsika: directory with CORSIKA (input) files
# /workdir/external/log:     directory for run scripts and pilot files
# /workdir/external/groptics:directory with GrOptics (output) files
# /workdir/GrOptics/Config:  directory into which model files
#                            (atmosphere, telescope model) are copied.
#

#####################################################################
# generate cleanup submission scripts
generate_cleanup_submission_script()
{
    CLEANUPSCRIPT="$1"
    OUTPUT_DIR="$2"
    CLEANUP_DATA_DIR="${DATA_DIR}/CLEANUP/"
    mkdir -p "${CLEANUP_DATA_DIR}"

    echo "#!/bin/bash" > "$CLEANUPSCRIPT.sh"
    echo "RUN_NUMBER=\$1" >> "$CLEANUPSCRIPT.sh"
    echo "rm -f \"${CLEANUP_DATA_DIR}/DAT\${RUN_NUMBER}.cleanup.log\"" >> "$CLEANUPSCRIPT.sh"
    echo "touch \"${CLEANUP_DATA_DIR}/DAT\${RUN_NUMBER}.cleanup.log\"" >> "$CLEANUPSCRIPT.sh"

    # log files
    echo "mkdir -p \"${DATA_DIR}/LOGFILES/\"" >> "$CLEANUPSCRIPT.sh"
    TAR_LOG_FILES="find ${DATA_DIR} -type f -name \"*\${RUN_NUMBER}*.log\" -print0 | tar -cvzf ${DATA_DIR}/LOGFILES/logs_\${RUN_NUMBER}.tar.gz --null -T -"
    echo "$TAR_LOG_FILES >> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"

    # CORSIKA - files are zipped
    CORSIKA_DATA_DIR="${DATA_DIR}/CORSIKA"
    # echo "bzip2 -f -v ${CORSIKA_DATA_DIR}/DAT\${RUN_NUMBER}.telescope >> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"
    # echo "bzip2 -f -v ${CORSIKA_DATA_DIR}/DAT\${RUN_NUMBER}.log >> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"
    # CORSIKA - result file is removed
    echo "rm -f -v ${CORSIKA_DATA_DIR}/DAT\${RUN_NUMBER}.telescope >> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"
    chmod u+x "$CLEANUPSCRIPT.sh"
    # GROPTICS - root files are removed
    CLEANUP_GROPTICS="find ${DATA_DIR}/GROPTICS/ -name \"DAT\${RUN_NUMBER}*.groptics.root\" -print -exec rm -f -v {} \\;" >> "$CLEANUPSCRIPT.sh"
    echo "$CLEANUP_GROPTICS >> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"
    # CARE std - root files are removed
    CLEANUP_CARE_std="find ${DATA_DIR}/CARE_std/ -name \"DAT\${RUN_NUMBER}*.care.root\" -print -exec rm -f -v {} \\;" >> "$CLEANUPSCRIPT.sh"
    echo "$CLEANUP_CARE_std >> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"
    # CARE redHV - root files are removed
    CLEANUP_CARE_redHV="find ${DATA_DIR}/CARE_redHV/ -name \"DAT\${RUN_NUMBER}*.care.root\" -print -exec rm -f -v {} \\;" >> "$CLEANUPSCRIPT.sh"
    echo "$CLEANUP_CARE_redHV>> $CLEANUP_DATA_DIR/DAT\${RUN_NUMBER}.cleanup.log 2>&1" >> "$CLEANUPSCRIPT.sh"

}
