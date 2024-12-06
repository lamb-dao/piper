#!/usr/bin/env bash

#strict mode
set -euo pipefail
IFS=$'\n\t'

## these calls all ensure nice log file handling
# single input interactive mode
# ./run.sh
# single input noninteractive
# ./run.sh full
# multiple inputs in inputBatch dir, noninteractive
# ./run.sh batch

# TODO directory creation should happen here before run calls piper

flag="${1:-default}"
# check and call a single non-interactive full run
if [ "${flag}" == "full" ]; then
    ./piper.sh batch 2>&1 | tee -a log.txt
    # check and setup and call multiple non-interactive full runs, removing files after
elif [ "${flag}" == "batch" ]; then
    # NOTE  to use batch argument, inputBatch must exist and contain batchFileType files
    batchFileType="vcf"
    cd inputBatch
    for f in "*.${batchFileType}"; do
        cp -rav ${f} ../input
	      cd ..
	      rn=$(echo ${f} | sed s/.${batchFileType}// )
        #call this run
        ./piper.sh batch 2>&1 | tee -a log_${rn}.txt
        # after run remove the used file
	      cd inputBatch
        rm ${v}
    done
# default call a single interactive run with option to subset input files
else
    ./piper.sh 2>&1 | tee -a log.txt
fi
