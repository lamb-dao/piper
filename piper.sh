#!/usr/bin/env bash

#strict mode
# https://gist.github.com/robin-a-meade/58d60124b88b60816e8349d1e3938615
set -euo pipefail
IFS=$'\n\t'

# tough, simple and airworthy pipeline template
# TODO ascii airplane
echo "===/-O-\=== Begin piper run!  ===/-O-\==="

# TODO add note on required environment

## use arg to set flag to skip interactive use
runMode=all
flag="${1:-default}"
if [ "${flag}" == "batch" ]; then
    runMode="${1}"
fi

## Setup mandatory locations
home=$(pwd)
checkpoints=${home}/checkpoints
# piper requires checkpoints; -p will check and create if necessary
mkdir -p ${checkpoints}

#### functions
function doStep () {
    # doStep stepName, to check if a step is incomplete, returns true if step is required
    ( cd ${checkpoints}
      n=$(ls -1 $1 2>/dev/null | wc -l)
      if [ "$n" -ne 1 ]; then
          #do it
          echo "check: $1 requires completion"
          return 0
      else
          #it is done
          echo "check: $1 is marked complete"
          return 1
    fi
    )
}

function userApprove () {
    #batch mode, no interactive user,  assume approval for all step
    if [ "${runMode}" == "batch" ]; then
        echo "Continuing"
        return 0
    fi
    # user continue or exit
    read -p "To continue enter y: " continue
    if [ "${continue}" != "y" ]; then
        echo "Exiting"
        exit 0
    fi
}

function markStep () {
    # markStep add stepname, to mark complete
    # markStep del stepname, to remove mark
    ( cd ${checkpoints}
      if [ "${1}" == "add" ]; then
          echo "check: ${2} will be marked complete"
          touch ${2}
      fi
      if [ "${1}" == "del" ]; then
          echo "check: ${2} will be UN marked"
          rm -f ${2}
      fi
    )
}

#begin block comment
:<<'MASK'
MASK
#end block comment

#===================
# clean data for this run, leave input and checkpoints
step="sweep_Begin"
if( doStep ${step} ); then
    echo "BEGIN: ${step}"
    userApprove
    rm -r ${data}
    mkdir -p ${data}
    touch ${data}/.gitkeep

    # for some uses cleaning output is recommended for guaranteed fresh results
    # for other uses the finalize (vvv) step is useful for dropping sets of data in output
    # rm -r ${output}
    # mkdir -p ${output}
    # touch ${output}/.gitkeep

    markStep add $step
fi
#===================

#===================
#Load input files from Input to Data, to guarantee beginning state is repeatable
step="copyIP"
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${input}
      # test if input state is as expected
      # eg only 1 vcf
      n=$(ls -1 *.vcf 2>/dev/null | wc -l)
      if [ "$n" -ne 1 ]; then
          echo "ERROR: there can only be one .vcf file in input"
          exit 1
      else
          vcf="$(pwd)/$(ls -1 *.vcf)"
          # full copy with a rename for uniformity
          # rsync -vah --progress ${vcf} ${data}/in.vcf
          #or
          # symlink copy with a rename for uniformity
          ln -s ${vcf} ${data}/in.vcf
          markStep add ${step}
      fi
    )
fi
#===================

#===================
## subset file for fast testing runs while building pipeline
step="subsetFile"
in="in.vcf"
out="${step}.vcf"
#markStep del $step #force do
# TODO use force skip turn subsetting off for full scale processing
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #optional only if interactive mode is on, in batch mode always use full file
    if [ "${runMode}" == "all" ]; then
        read -p "To filter the ENTIRE variant file enter y, otherwise create a subset: " continue
        if [ "${continue}" = "y" ]; then
            echo "Continue with full variant file"
        else
            samplingRate="0.05"
            echo "ALERT: Subsampling the input file for testing!"
            echo "samplingRate=${samplingRate}"
            ( cd ${data}
              check=$(ls -1 ${in})
              vcfrandomsample -p 777 -r ${samplingRate} ${in} > ${out}
            )
        fi
    fi
    markStep add $step
fi
#===================

#===================
# user can skip subset step, this will handle the cases
step="handleSubset"
inFull="in.vcf"
inSub="subsetFile.vcf"
out="start.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    ( cd ${data}
      if [ -e "${inSub}" ]; then
          echo "ALERT: A subset file was created"
          ln -s "${inSub}" "${out}"
      elif [ -e "${inFull}" ]; then
          echo "A subset file was not created. Continue the pipeline to process at full scale, this will take time but give the best results."
          ln -s "${inFull}" "${out}"
      else
          echo "ERROR: either ${inFull} or ${inSub} must exist"
          exit 1
      fi
      #materialize the symlink
      rsync -Lvh --progress ${out} ${out}.real
      rm ${out}
      mv ${out}.real ${out}
    )
    markStep add $step
fi
#===================

#===================
# TODO USER specify for current use
step="templateStep_1"
in="${out}" #grab last steps output
out="${step}.filetype" #set this steps major target output
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${data}
      echo "This step will do some action on ${in}" > ${out}
      echo -e "PIPER\t${step}\tFiles: ${in} ${out}\tOther interesting inter-run data for this step"
    )
    markStep add $step
fi
#===================

#===================
# TODO USER specify for current use
step="templateStep_2"
in="${out}" #grab last steps output
out="${step}.filetype" #set this steps major target
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${data}
      echo "This step will do some action on ${in}" > ${out}
      echo -e "PIPER\t${step}\tFiles: ${in} ${out}\tOther interesting inter-run data for this step"
    )
    markStep add $step
fi
#===================

#===================
# for this run extract summary lines from full log for inter-run comparison
step="piper_summary"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    cat log*.txt | grep PIPER > ${data}/summary.raw.txt
    #log is cumulative of all runs, to get last instance of a step, flip and take first unique
    ( cd ${data}
      tac summary.raw.txt \
          | awk '!seen[$2]++' \
          | tac - \
          > summary.txt
    )
    markStep add $step
fi
#===================

#===================
# create a unique dir of outputs for this run, log summary and files.
# when complete place in main outputs dir
step="finalize"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    cp log*.txt ${data}
    # TODO cat a copy of this file as well so step arguments are documented
    ( cd ${data}
      #attach an important input file name to the dirname of these outputs for tracking
      # TODO USER set for current use
      #eg: get a vcf file, strip the filetype
      runName=$(cd ${input}; n="*.vcf"; echo ${n} | sed s/.vcf//)
      op="OP_${runName}"

      #make new unique dir
      rm -r ${op} || echo ""
      mkdir -p ${op}/logs
      #package logging outputs
      cp summary.txt ${op}
      cp log*.txt ${op}/logs
      #package data outputs
      # TODO USER set files being copied for current use
      # cp *.vcf ${op}
      # cp *.log ${op}/logs #error here
      # cp *.pdf ${op}
      # cp *.png ${op}

      #push the complete set of outputs once
      mv -f ${op} ${output}
    )
    markStep add $step
fi
#===================

#===================
# full reset for the next run. Remove inputs, checkpoints, run data, run logs
step="sweep_End"
#markStep del $step #force do
markStep add $step #force skip by default. This step removes all input, ensure original files are archived.
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${input}
      rm * || echo ""
      cd ${checkpoints}
      rm * || echo ""
      cd ${data}
      rm -r * || echo ""
      cd ..
      rm log*.txt
    )
fi
#===================

###################################
echo "===/-O-\=== End of piper run!  ===/-O-\==="
exit 0
###################################

#===================
step="templateStep"
in="${out}" #grab last steps output
out="${step}.filetype" #set this steps major target
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${data}
      echo "This step will do some action on ${in}" > ${out}
      exitStatus=$?
      # tab delimited data from action steps, must begin with PIPER\t${step}\t
      echo -e "PIPER\t${step}\tFiles:\t${in}\t${out}\tExitStatus:\t${exitStatus}"
    )
    markStep add $step
fi
#===================








Below is example use of step linking with in/out and other more complex use

#===================
# manipulates dataField names which differ due to caller
step="renameFields"
in="filterStart.vcf"
#markStep del $step #force do
#markStep add $step #force skip, it is better to try to get bcf filters to handle high precision filters where names are inconsistent with vcftools filter assumptions. This may not be possible
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    # rename NR to DP
    ( cd ${data}
      #FORMAT=<ID=NR
      sed -i "s/FORMAT=<ID=NR/FORMAT=<ID=DP/g" ${in}
      #:NR
      sed -i "s/:NR/:DP/g" ${in}
      sed -i "s/:NR:/:DP:/g" ${in}
    )
    markStep add $step
fi
#===================

#===================
# retains bi-allelic snps only
step="removeIndels"
in="filterStart.vcf"
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --remove-indels \
          --min-alleles 2 \
          --max-alleles 2 \
          --recode \
          --recode-INFO-all \
          --out ${step}
      echo -e "SUMMARY\tSTEP\tPERCENT_CUT\tVARS_KEPT"
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
# remove sites below MQx phred scale
step="minQuality"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --minQ 30 \
          --recode \
          --recode-INFO-all \
          --out ${step}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
# set to missing any genotypes below GQx (phred score)
step="minQualityGT"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --minGQ 30 \
          --recode \
          --recode-INFO-all \
          --out ${step}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
# exclude sites with less than x(integer count) total observations, used to remove noise and erronious sequencing
step="minorAlleleCount"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --mac 2 \
          --recode \
          --recode-INFO-all \
          --out ${step}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
# set to missing any genotypes with less than x(integer count) reads
step="minDepth"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --minDP 5 \
          --recode \
          --recode-INFO-all \
          --out ${step}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
# set to missing any genotypes with more than x(integer count) reads
step="maxDepth"
in="${out}" #grab last steps output
out="${step}.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      bcftools filter \
               --threads 24 \
               --e 'DP > 400' \
               --set-GTs . \
               -O v \
               -o "${step}.vcf" \
               ${in}
      rm -f XP_*
      crossPlot ${step} DP ${in} ${out}
      multiPlot DP Depth ${out}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
step="minQualDepth"
in="${out}" #grab last steps output
out="${step}.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      bcftools filter \
               --threads 24 \
               --e 'QD < 3' \
               -O v \
               -o "${step}.vcf" \
               ${in}
      rm -f XP_*
      crossPlot ${step} QD ${in} ${out}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================


#===================
# exclude individuals sequenced at less than x(ratio) sites
step="maxMissingBySample"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${data}
      #report on all samples
      vcftools \
          --vcf "${in}" \
          --missing-indv
      #find samples above cutoff
      cutoff=0.88
      awk -v co="${cutoff}" '{if ($5<co) print $1}' out.imiss > out.imiss.keep
      awk -v co="${cutoff}" '{if ($5>=co) print $1}' out.imiss > out.imiss.drop
      #remove samples above cutoff
      vcftools \
                  --vcf "${in}" \
                  --keep out.imiss.keep \
                  --recode \
                  --recode-INFO-all \
                  --out "${step}"
      #report
      echo "DROPPING"
      awk  '{print $1}' out.imiss.drop
      echo -e "LINE\tMISSING"
      sort -t$'\t' -k 5 -n -r out.imiss > out.imiss.sort
      awk  '{print $1"\t"$5}' out.imiss.sort
      echo -e "SUMMARY\t${step}\t$(compareFiles line out.imiss out.imiss.keep)\tkeep $(cat out.imiss.keep | wc -l) individuals"
    )
    markStep add $step
fi
#===================

#===================
# exclude sites sequenced in less than x(ratio) of the individuals
step="maxMissingBySite"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    #
    ( cd ${data}
      vcftools \
              --vcf ${in} \
              --max-missing 0.90 \
              --recode \
              --recode-INFO-all \
              --out ${step}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
step="minorAlleleFreq"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --maf 0.05 \
          --recode \
          --recode-INFO-all \
        --out ${step}
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================

#===================
step="allelicBalance"
in="${out}" #grab last steps output
out="${step}.recode.vcf"
#markStep del $step #force do
#markStep add $step #force skip
if( doStep $step ); then
    echo "BEGIN: ${step}"
    userApprove
    ( cd ${data}
      vcftools \
          --vcf ${in} \
          --freq2
      awk '{if ($5>0.25 && $5<0.75) print $1"\t"$2}' out.frq > out.frq.keep
      vcftools \
          --vcf "${in}" \
          --positions out.frq.keep \
          --recode \
          --recode-INFO-all \
          --out "${step}"
      echo -e "SUMMARY\t${step}\t$(compareFiles vars ${in} ${out})\t$(varCount ${out})"
    )
    markStep add $step
fi
#===================
