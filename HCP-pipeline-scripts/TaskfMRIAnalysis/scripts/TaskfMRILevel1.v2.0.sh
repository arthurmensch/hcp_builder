#!/bin/bash
# Modified by Arthur Mensch to recompute StandardCoordinates statistics

set -e
g_script_name=`basename ${0}`

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

Subject="$1"
log_Msg "Subject: ${Subject}"

ResultsFolder="$2"
log_Msg "ResultsFolder: ${ResultsFolder}"

LevelOnefMRIName="$3"
log_Msg "LevelOnefMRIName: ${LevelOnefMRIName}"

LevelOnefsfName="$4"
log_Msg "LevelOnefsfName: ${LevelOnefsfName}"

OriginalSmoothingFWHM="$5"
log_Msg "OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"

Confound="$6"
log_Msg "Confound: ${Confound}"

FinalSmoothingFWHM="$7"
log_Msg "FinalSmoothingFWHM: ${FinalSmoothingFWHM}"

TemporalFilter="$8"
log_Msg "TemporalFilter: ${TemporalFilter}"

RegName="$9"
log_Msg "RegName: ${RegName}"

show_tool_versions

if [ ! ${RegName} = "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
fi
log_Msg "RegString: ${RegString}"

TR_vol=`fslinfo ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}.nii.gz | grep pixdim4 | awk '{print $2}'`
log_Msg "TR_vol: ${TR_vol}"

#Only do the additional smoothing required to hit the target final smoothing for CIFTI.  Additional smoothing is not recommended, if looking for area-sized effects use parcellation for greater sensitivity and satistical power
AdditionalSmoothingFWHM=`echo "sqrt(( $FinalSmoothingFWHM ^ 2 ) - ( $OriginalSmoothingFWHM ^ 2 ))" | bc -l`
log_Msg "AdditionalSmoothingFWHM: ${AdditionalSmoothingFWHM}"

AdditionalSigma=`echo "$AdditionalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
log_Msg "AdditionalSigma: ${AdditionalSigma}"

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"
log_Msg "SmoothingString: ${SmoothingString}"
log_Msg "TemporalFilterString: ${TemporalFilterString}"

FEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}.feat"
log_Msg "FEATDir: ${FEATDir}"
if [ -e ${FEATDir} ] ; then
  rm -r ${FEATDir}
  mkdir ${FEATDir}
else
  mkdir -p ${FEATDir}
fi

if [ $TemporalFilter = "200" ] ; then
  #Don't edit the fsf file if the temporal filter is the same
  log_Msg "Don't edit the fsf file if the temporal filter is the same"
  cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf ${FEATDir}/temp.fsf
else
  #Change the highpass filter string to the desired highpass filter
  log_Msg "Change the highpass filter string to the desired highpass filter"
  cat ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf | sed s/"set fmri(paradigm_hp) \"200\""/"set fmri(paradigm_hp) \"${TemporalFilter}\""/g > ${FEATDir}/temp.fsf
fi

#Change smoothing to be equal to additional smoothing in FSF file and change output directory to match total smoothing and highpass
log_Msg "Change smoothing to be equal to additional smoothing in FSF file and change output directory to match total smoothing and highpass"
cat ${FEATDir}/temp.fsf | sed s/"set fmri(smooth) \"4\""/"set fmri(smooth) \"${AdditionalSmoothingFWHM}\""/g | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}${RegString}/g > ${FEATDir}/design.fsf
rm ${FEATDir}/temp.fsf

#Create design files, model confounds if desired
log_Msg "Create design files, model confounds if desired"
DIR=`pwd`
cd ${FEATDir}
if [ $Confound = "NONE" ] ; then
  feat_model ${FEATDir}/design
else
  feat_model ${FEATDir}/design ${ResultsFolder}/${LevelOnefMRIName}/${Confound}
fi
cd $DIR

#Prepare files and folders
log_Msg "Prepare files and folders"
DesignMatrix=${FEATDir}/design.mat
DesignContrasts=${FEATDir}/design.con
DesignfContrasts=${FEATDir}/design.fts

###Standard NIFTI Volume-based Processsing###
log_Msg "Standard NIFTI Volume-based Processsing"
#Add volume smoothing
log_Msg "Add volume smoothing"
FinalSmoothingSigma=`echo "$FinalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_SBRef.nii.gz -bin -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_weight -odt float
fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}.nii.gz -kernel gauss ${FinalSmoothingSigma} -fmean -div ${FEATDir}/mask_weight -mas ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_SBRef.nii.gz ${FEATDir}/${LevelOnefMRIName}"$SmoothingString".nii.gz -odt float

#Add temporal filtering
log_Msg "Add temporal filtering"
fslmaths ${FEATDir}/${LevelOnefMRIName}"$SmoothingString".nii.gz -bptf `echo "0.5 * $TemporalFilter / $TR_vol" | bc -l` -1 ${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz

#Run film_gls on subcortical volume data
log_Msg "Run film_gls on subcortical volume data"
film_gls --rn=${FEATDir}/StandardVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} --fcon=${DesignfContrasts} --thr=1000
