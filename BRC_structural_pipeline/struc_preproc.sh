#!/bin/bash
# Last update: 19/05/2019

# Authors: Ali-Reza Mohammadi-Nejad, & Stamatios N Sotiropoulos
#
# Copyright 2018 University of Nottingham

# -e  Exit immediately if a command exits with a non-zero status.
set -e

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

Usage()
{
  echo " "
  echo " "
  echo "`basename $0`: Description"
  echo " "
  echo "Usage: `basename $0`"
  echo "Compulsory arguments (You MUST set one or more of):"
  echo " --input <path>                   Full path of the input T1w image (for one image only)"
  echo " --path <path>                    Output path"
  echo " --subject <subject name>         Output directory is a subject name folder in output path directory"
  echo " "
  echo "Optional arguments (You may optionally specify one or more of):"
  echo " --t2 <path>                      Full path of the input T2W image (for processing of T2 data)"
  echo " --freesurfer                     Turn on Freesurfer processing pipeline"
  echo " --subseg                         Turn on subcortical segmentation by FIRST"
  echo " --qc                             Turn on quality control of T1 data"
  echo " --strongbias                     Turn on for images with very strong bias fields"
  echo " --noreg                          Turn off steps that do registration to standard (FLIRT and FNIRT)"
  echo " --noseg                          Turn off the step that does tissue-type segmentation (FAST)"
  echo " --nocrop                         Turn off the step that does automated cropping"
  echo " --nodefacing                     Turn off the step that does automated brain defacing"
  echo " --regtype <method>               The registration method for the registration of structural data to the standard space"
  echo "                                      1: Linear,"
  echo "                                      2: Linear + Non-linear (default value). Here, the linear transformation is used as an initialization step for the Non-linear registration"
  echo " --help                           help"
  echo " "
  echo " "
}

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi

################################################## OPTION PARSING #####################################################

log=`echo "$@"`

# default values
Sub_ID=""
IN_Img=""
Path=""
T2_IN_Img=""

T2="no"
do_Sub_seg="no"
do_QC="no"
do_freesurfer="no"
do_tissue_seg="yes"
do_anat_based_on_FS="yes"
do_crop="yes"
do_defacing="yes"
RegType="2"

Opt_args="--clobber"

# parse arguments
while [ "$1" != "" ]; do
    case $1 in
        --subject )             shift
                                Sub_ID=$1
                                ;;

        --path )                shift
				                        Path=$1
                                ;;

        --input )               shift
				                        IN_Img=$1
                                ;;

        --t2 )                  shift
				                        T2_IN_Img=$1
                		            T2=yes
                                ;;

        --subseg )           	  do_Sub_seg=yes
                                ;;

        --qc )           	      do_QC=yes
                                ;;

        --strongbias )          Opt_args="$Opt_args --strongbias"
                                ;;

        --noreg )          	    Opt_args="$Opt_args --noreg"
                                ;;

        --noseg )         	    Opt_args="$Opt_args --noseg"
                                do_tissue_seg=no
                                ;;

        --freesurfer )         	do_freesurfer=yes
                                ;;

        --nocrop)               do_crop="no";
                                ;;

        --nodefacing)           do_defacing="no";
                                ;;

        --regtype )             shift
                                RegType=$1
                                ;;

        --help )                Usage
                                exit
                                ;;

        * )                     Usage
                                exit 1
    esac
    shift
done

#=====================================================================================
###                          Sanity checking of arguments
#=====================================================================================
if [ X$Sub_ID = X ] && [ X$IN_Img = X ] && [ X$Path = X ] ; then
    echo "All of the compulsory arguments --path, -i and -s MUST be used"
    exit 1;
fi

#Set fsl_anat options
if [ $do_Sub_seg = "no" ] ; then
    Opt_args="$Opt_args --nosubcortseg"
fi
if [ $do_crop = "no" ] ; then
    Opt_args="$Opt_args --nocrop"
fi

Opt_args="$Opt_args -t $FAST_t"

#=====================================================================================
###                                Naming Conventions
#=====================================================================================

AnalysisFolderName="analysis"
AnatMRIFolderName="anatMRI"
T1FolderName="T1"
T2FolderName="T2"
rawFolderName="raw"
preprocessFolderName="preproc"
processedFolderName="processed"
tempFolderName="temp"
logFolderName="log"
regFolderName="reg"
qcFolderName="qc"
biasFolderName="bias"
dataFolderName="data"
data2stdFolderName="data2std"
segFolderName="seg"
FSFolderName="FS"
FastFolderName="FAST"
FirstFolderName="FIRST"

log_Name="log.txt"

#=====================================================================================
###                                  Setup PATHS
#=====================================================================================

O_DIR=$Path/${Sub_ID};
if [ ! -d "$O_DIR" ]; then
    mkdir -p $O_DIR;
#else
#  O_DIR="${O_DIR}_$(date +"%d-%m-%Y_%H-%M")"
#  mkdir $O_DIR
fi

AnalysisFolder=${O_DIR}/${AnalysisFolderName}
AnatMRIFolder=${AnalysisFolder}/${AnatMRIFolderName}
rawFolder=${O_DIR}/${rawFolderName}
AnatMRIrawFolder=${rawFolder}/${AnatMRIFolderName}
T1Folder=${AnatMRIFolder}/${T1FolderName}
rawT1Folder=${AnatMRIrawFolder}/${T1FolderName}
preprocT1Folder=${T1Folder}/${preprocessFolderName}
processedT1Folder=${T1Folder}/${processedFolderName}
logT1Folder=${T1Folder}/${logFolderName}
TempT1Folder=${T1Folder}/${tempFolderName}
FastT1Folder=${TempT1Folder}/${FastFolderName}
FirstT1Folder=${TempT1Folder}/${FirstFolderName}
regTempT1Folder=${TempT1Folder}/${regFolderName}
regT1Folder=${preprocT1Folder}/${regFolderName}
qcT1Folder=${preprocT1Folder}/${qcFolderName}
biasT1Folder=${preprocT1Folder}/${biasFolderName}
dataT1Folder=${processedT1Folder}/${dataFolderName}
data2stdT1Folder=${processedT1Folder}/${data2stdFolderName}
segT1Folder=${processedT1Folder}/${segFolderName}
FSFolder=${processedT1Folder}/${FSFolderName}
rawT2Folder=${AnatMRIrawFolder}/${T2FolderName}
T2Folder=${AnatMRIFolder}/${T2FolderName}
preprocT2Folder=${T2Folder}/${preprocessFolderName}
processedT2Folder=${T2Folder}/${processedFolderName}
dataT2Folder=${processedT2Folder}/${dataFolderName}
data2stdT2Folder=${processedT2Folder}/${data2stdFolderName}
regT2Folder=${preprocT2Folder}/${regFolderName}
TempT2Folder=${T2Folder}/${tempFolderName}
regTempT2Folder=${TempT2Folder}/${regFolderName}

#Check existance of foldersa= and then create them
if [ ! -d ${AnalysisFolder} ]; then mkdir ${AnalysisFolder}; fi
if [ ! -d ${AnatMRIFolder} ]; then mkdir ${AnatMRIFolder}; fi
if [ ! -d ${rawFolder} ]; then mkdir ${rawFolder}; fi
if [ ! -d ${AnatMRIrawFolder} ]; then mkdir ${AnatMRIrawFolder}; fi
if [ ! -d ${T1Folder} ]; then mkdir ${T1Folder}; fi
if [ ! -d ${rawT1Folder} ]; then mkdir ${rawT1Folder}; fi
if [ ! -d ${preprocT1Folder} ]; then mkdir ${preprocT1Folder}; fi
if [ ! -d ${processedT1Folder} ]; then mkdir ${processedT1Folder}; fi
if [ -e ${logT1Folder} ] ; then rm -r ${logT1Folder}; fi; mkdir ${logT1Folder}
if [ ! -d ${TempT1Folder} ]; then mkdir ${TempT1Folder}; fi
if [ ! -d ${regT1Folder} ]; then mkdir ${regT1Folder}; fi
if [ ! -d ${qcT1Folder} ]; then mkdir ${qcT1Folder}; fi
if [ ! -d ${biasT1Folder} ]; then mkdir ${biasT1Folder}; fi
if [ ! -d ${dataT1Folder} ]; then mkdir ${dataT1Folder}; fi
if [ ! -d ${data2stdT1Folder} ]; then mkdir ${data2stdT1Folder}; fi
if [ ! -d ${segT1Folder} ]; then mkdir ${segT1Folder}; fi


if [[ $T2 == yes ]]; then
    if [ ! -d ${T2Folder} ]; then mkdir ${T2Folder}; fi
    if [ ! -d ${rawT2Folder} ]; then mkdir ${rawT2Folder}; fi
    if [ ! -d ${preprocT2Folder} ]; then mkdir ${preprocT2Folder}; fi
    if [ ! -d ${processedT2Folder} ]; then mkdir ${processedT2Folder}; fi
    if [ ! -d ${dataT2Folder} ]; then mkdir ${dataT2Folder}; fi
    if [ ! -d ${data2stdT2Folder} ]; then mkdir ${data2stdT2Folder}; fi
    if [ ! -d ${regT2Folder} ]; then mkdir ${regT2Folder}; fi
    if [ ! -d ${TempT2Folder} ]; then mkdir ${TempT2Folder}; fi
fi

#=====================================================================================
###                              Setup the Log file
#=====================================================================================

${RUN} ${BRCDIR}/Show_version.sh \
      --showdiff="no" \
      --logfile=${logT1Folder}/${log_Name}
Start_Time="$(date -u +%s)"

source $BRC_GLOBAL_SCR/log.shlib  # Logging related functions
log_SetPath "${logT1Folder}/${log_Name}"

log_Msg 2 "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
log_Msg 2 "Original command:"
log_Msg 2 "$log"
log_Msg 2 "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
log_Msg 2 "Parsing Command Line Options"
log_Msg 2 "Sub_ID: $Sub_ID"
log_Msg 2 "Path: $Path"
log_Msg 2 "IN_Img: $IN_Img"
log_Msg 2 "T2_IN_Img: $T2_IN_Img"
log_Msg 2 "do_Sub_seg: $do_Sub_seg"
log_Msg 2 "do_QC: $do_QC"
log_Msg 2 "do_tissue_seg: $do_tissue_seg"
log_Msg 2 "do_freesurfer: $do_freesurfer"
log_Msg 2 "RegType: $RegType"
log_Msg 2 "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

#=====================================================================================
###                                   DO WORK
#=====================================================================================

log_Msg 3 "OutputDir is: ${AnatMRIFolder}"

$FSLDIR/bin/imcp ${IN_Img} ${rawT1Folder}/T1_orig.nii.gz

if [[ $T2 == "yes" ]]; then
    $FSLDIR/bin/imcp $T2_IN_Img ${rawT2Folder}/T2_orig.nii.gz
fi

if [ $CLUSTER_MODE = "YES" ] ; then

#    export MODULEPATH=/gpfs01/software/imaging/modulefiles:$MODULEPATH
#
#    module load cuda/local/9.2
#    module load fsl-img/5.0.11
#    module load ica-aroma-img/py2.7/0.3
#    ${JOBSUBpath}/jobsub -q cpu -p 1 -s BRCP_SMRI_${Subject} -t 00:46:00 -m 60 -c "${BRC_SCTRUC_DIR}/struc_preproc.sh --subject ${Sub_ID} --path ${Path} --input ${IN_Img} --t2 ${T2_IN_Img} ${Opt_args}" &


    jobID1=`${JOBSUBpath}/jobsub -q cpu -p 1 -s BRC_SMRI_${Subject} -t 03:00:00 -m 60 -c "${BRC_SCTRUC_SCR}/struc_preproc_part_1.sh --tempt1folder=${TempT1Folder} --rawt1folder=${rawT1Folder} --dosubseg=${do_Sub_seg} --dotissueseg=${do_tissue_seg} --docrop=${do_crop} --dodefacing=${do_defacing} --fastt1folder=${FastT1Folder} --firstt1folder=${FirstT1Folder} --regtempt1folder=${regTempT1Folder} --t2=${T2} --tempt2folder=${TempT2Folder} --rawt2folder=${rawT2Folder} --regtempt2folder=${regTempT2Folder} --t1folder=${T1Folder} --t2folder=${T2Folder} --biast1folder=${biasT1Folder} --datat1folder=${dataT1Folder} --data2stdt1folder=${data2stdT1Folder} --segt1folder=${segT1Folder} --regt1folder=${regT1Folder} --datat2folder=${dataT2Folder} --data2stdt2folder=${data2stdT2Folder} --regt2folder=${regT2Folder} --dofreesurfer=${do_freesurfer} --processedt1folder=${processedT1Folder} --fsfoldername=${FSFolderName} --starttime=${Start_Time} --subid=${Sub_ID} --regtype=${RegType} --logt1folder=${logT1Folder}/${log_Name}" &`
    jobID1=`echo -e $jobID1 | awk '{ print $NF }'`
    echo "jobID_1: ${jobID1}"

else

    ${BRC_SCTRUC_SCR}/struc_preproc_part_1.sh \
                      --tempt1folder=${TempT1Folder} \
                      --rawt1folder=${rawT1Folder} \
                      --dosubseg=${do_Sub_seg} \
                      --dotissueseg=${do_tissue_seg} \
                      --docrop=${do_crop} \
                      --dodefacing=${do_defacing} \
                      --fastt1folder=${FastT1Folder} \
                      --firstt1folder=${FirstT1Folder} \
                      --regtempt1folder=${regTempT1Folder} \
                      --t2=${T2} \
                      --tempt2folder=${TempT2Folder} \
                      --rawt2folder=${rawT2Folder} \
                      --regtempt2folder=${regTempT2Folder} \
                      --t1folder=${T1Folder} \
                      --t2folder=${T2Folder} \
                      --biast1folder=${biasT1Folder} \
                      --datat1folder=${dataT1Folder}  \
                      --data2stdt1folder=${data2stdT1Folder} \
                      --segt1folder=${segT1Folder} \
                      --regt1folder=${regT1Folder} \
                      --datat2folder=${dataT2Folder} \
                      --data2stdt2folder=${data2stdT2Folder} \
                      --regt2folder=${regT2Folder} \
                      --dofreesurfer=${do_freesurfer} \
                      --processedt1folder=${processedT1Folder} \
                      --fsfoldername=${FSFolderName} \
                      --starttime=${Start_Time} \
                      --subid=${Sub_ID} \
                      --regtype=${RegType} \
                      --logt1folder=${logT1Folder}/${log_Name}

fi
