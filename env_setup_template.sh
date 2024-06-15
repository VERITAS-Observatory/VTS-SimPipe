#!/bin/bash
# Project wide environment variables

# log files, submission scripts, etc.
export VTSSIMPIPE_LOG_DIR=vtssimpipe_log_dir
# output directory
export VTSSIMPIPE_DATA_DIR=vtssimpipe_corsika_dir
# container type
export VTSSIMPIPE_CONTAINER="apptainer"
# export VTSSIMPIPE_CONTAINER="docker"
# package url (docker style)
export VTSSIMPIPE_CONTAINER_URL="ghcr.io/veritas-observatory/"
# apptainers are stored in this directory
export VTSSIMPIPE_CONTAINER_DIR=vtssimpipe_containe_dir
# CORSIKA
export VTSSIMPIPE_CORSIKA_IMAGE="vtsimpipe-corsika-avx2:2.0.0"
# GROPTICS
export VTSSIMPIPE_GROPTICS_IMAGE="vtsimpipe-groptics:2.0.0"
# CARE
export VTSSIMPIPE_CARE_IMAGE="vtsimpipe-care:2.0.0"
# MERGEVBF
export VTSSIMPIPE_MERGEVBF_IMAGE="vtsimpipe-mergevbf:2.0.0"
