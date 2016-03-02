# QualityProcess.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N QualityProcess
#PBS -q first
#PBS -l nodes=1:ppn=1,mem=40gb
#PBS -l walltime=500:00:00
#PBS -j oe
#PBS -V
#PBS -A schloss_lab

############################
# Load in Required Modules #
############################
module load R/3.2.3

##################
# Set Script Env #
##################

# Set the variables to be used in this script
export WorkingDirectory=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ColonCancerVirome/data
export Output='QualitySeqs'
export Figures=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ColonCancerVirome/figures

export MappingFile=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ColonCancerVirome/data/NexteraXT001Map.tsv

export LocalBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ColonCancerVirome/bin
export CutAdapt=/mnt/EXT/Schloss-data/bin/cutadapt-1.9.1/bin/cutadapt
export DeconsSeq=/mnt/EXT/Schloss-data/bin/deconseq-standalone-0.4.3/deconseq.pl
export fastx=/home/ghannig/bin/fastq_quality_trimmer

export RawSequenceDir=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ColonCancerVirome/data/rawFastq/NexteraXT001
export 16sRef=/mnt/EXT/Schloss-data/dbs/Silva_seed_v123/silva_bacteria_seed_v123

# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

###################
# Set Subroutines #
###################
# Some of these look simple, but this is an easy way to ensure the parameters are standardized
# across multiple calls of all subroutines.

runCutadaptWithMap () {
	echo Input fastq = ${1} #1 = full path to fastq file to be trimmed
	echo Mapping file = ${2} #2 = full path to mapping file mapping file
	echo Output file = ${3} #3 = full path for output directory
	export SAMPLEID=$(echo ${1} | sed 's/_L001.*//g')
	export THREEPRIME=$(awk --assign sampleid=$SAMPLEID '$2 == sampleid { print $22 }' ${2})
	export FIVEPRIME=$(awk --assign sampleid=$SAMPLEID '$2 == sampleid { print $19 }' ${2})
	python2.7 ${CutAdapt} --error-rate=0.1 --overlap=10 -a $THREEPRIME -a $FIVEPRIME ${1} > ${3}
}

runFastx () {
	${fastx} -t 33 -Q 33 -l 150 -i ${1} -o ${2}
}

runDeconSeq () {
	# # This is set for mouse decontamination
	perl ${DeconsSeq} -f ${1} -dbs mmref -out_dir ${2}
	mv ${2}/*clean.fq ${3}
	mv ${2}/*cont.fq ${4}
	rm -r ${2}
}

GetReadCount () {
	# WARNING: remove the appended file before running this through a loop
	echo Sample Name is ${1}
	echo Catg is ${2}
	export LineCount=$(wc -l ${3} | sed 's/ .*//')
	awk --assign count=$LineCount --assign name=${1} --assign catg=${2} ' BEGIN { print name"\t"catg"\t"count/4 }' >> ${4}
}

GetPercent () {
	echo Sample Name is ${1}
	export Clean=$(wc -l ${2} | sed 's/ .*//')
	export Cont=$(wc -l ${3} | sed 's/ .*//')
	awk --assign name=${1} --assign clean=${Clean} --assign cont=${Cont} 'BEGIN { print name"\tPercentCont\t"100*cont/(clean+cont) }' >> ${4}
}

16sContaminationEst () {
	echo Running 16S contamination estimation...
	# Make sure input is fasta
	blastn \
		-query ${2} \
		-out ${2}.tmp \
		-db /mnt/EXT/Schloss-data/dbs/Silva_seed_v123/silva_bacteria_seed_v123 \
		-outfmt 6 \
		-evalue 1e-10 \
		-max_target_seqs 1

	# Get the unique 16S hits for the sample
	cut -f 2 ${2}.tmp \
		| sort \
		| uniq \
		> ${2}.tmp2

	export HitCount=$(wc -l ${2}.tmp2 | sed 's/ .*//')
	export TotalCount=$(wc -l ${2} | sed 's/ .*//')

	# Create table with contamination information
	awk --assign name=${1} --assign hitcount=${HitCount} -assign totalcount=${TotalCount} 'BEGIN { print name"\tPercent16sHits\t"100*hitcount/(totalcount/2) }' >> ${3}

	# Remove the tmp file
	rm ${2}.tmp
	rm ${2}.tmp2
}

# Get them subroutines
export -f runCutadaptWithMap
export -f runFastx
export -f runDeconSeq
export -f GetReadCount
export -f GetPercent
export -f 16sContaminationEst

#######################################
# Remove Appended Files Before Adding #
#######################################
rm ./${Output}/SequenceCounts/RawAndFinalCounts.tsv
rm ./${Output}/SequenceCounts/ContaminationCounts.tsv
rm ./${Output}/SequenceCounts/PercentContamination.tsv
rm ./${Output}/SequenceCounts/16sHits.tsv

############
# Run Data #
############
for name in $(awk '{ print $2 }' ${MappingFile}); do
	# Because we are dealing with both directions
	for primer in R1 R2; do
		echo Processing sample ${name} and primer ${primer}...
		# mkdir ./${Output}/CutAdapt
		# runCutadaptWithMap \
		# 	${RawSequenceDir}/${name}*${primer}*.fastq \
		# 	${MappingFile} \
		# 	./${Output}/CutAdapt/${name}_${primer}.fastq

		# mkdir ./${Output}/FastxTrim
		# runFastx \
		# 	./${Output}/CutAdapt/${name}_${primer}.fastq \
		# 	./${Output}/FastxTrim/${name}_${primer}.fastq

		# mkdir ./${Output}/DeconSeq
		# runDeconSeq \
		# 	./${Output}/FastxTrim/${name}_${primer}.fastq \
		# 	./${Output}/DeconSeq/${name}_${primer}.fastq \
		# 	./${Output}/DeconSeq/${name}_${primer}_clean.fastq \
		# 	./${Output}/DeconSeq/${name}_${primer}_cont.fastq

		mkdir ./${Output}/SequenceCounts
		# Get raw and filtered counts
		GetReadCount \
			${name}_${primer} \
			'Raw' \
			${RawSequenceDir}/${name}*${primer}*.fastq \
			./${Output}/SequenceCounts/RawAndFinalCounts.tsv
		GetReadCount \
			${name}_${primer} \
			'Final' \
			./${Output}/DeconSeq/${name}_${primer}_clean.fastq \
			./${Output}/SequenceCounts/RawAndFinalCounts.tsv

		# Get counts for mouse contamination
		GetReadCount \
			${name}_${primer} \
			'Cont' \
			./${Output}/DeconSeq/${name}_${primer}_cont.fastq \
			./${Output}/SequenceCounts/ContaminationCounts.tsv
		GetReadCount \
			${name}_${primer} \
			'Clean' \
			./${Output}/DeconSeq/${name}_${primer}_clean.fastq \
			./${Output}/SequenceCounts/ContaminationCounts.tsv
		GetPercent \
			${name}_${primer} \
			./${Output}/DeconSeq/${name}_${primer}_clean.fastq \
			./${Output}/DeconSeq/${name}_${primer}_cont.fastq \
			./${Output}/SequenceCounts/PercentContamination.tsv

		# Convert fastq file to fasta
		/home/ghannig/bin/fastq_to_fasta \
			-i ./${Output}/DeconSeq/${name}_${primer}_clean.fastq \
			-o ./${Output}/DeconSeq/${name}_${primer}_clean.fasta

		# Compare bacterial contamination
		16sContaminationEst \
			${name}_${primer} \
			./${Output}/DeconSeq/${name}_${primer}_clean.fasta \
			./${Output}/SequenceCounts/16sHits.tsv
	done
done

# Plot the resulting sequence count files
Rscript ${LocalBin}/RunReadCountStats.R \
	-c ./${Output}/SequenceCounts/RawAndFinalCounts.tsv \
	-o ${Figures}/RawAndFinalCounts.pdf \
	-t "Read Count Before & After QC"

Rscript ${LocalBin}/RunReadCountStats.R \
	-c ./${Output}/SequenceCounts/ContaminationCounts.tsv \
	-o ${Figures}/ContaminationCounts.pdf \
	-t "Read Count Before & After Mouse Removal" \
	--log

Rscript ${LocalBin}/RunReadCountStats.R \
	-c ./${Output}/SequenceCounts/PercentContamination.tsv \
	-o ${Figures}/PercentContamination.pdf \
	-t "PercentContamination"

Rscript ${LocalBin}/RunReadCountStats.R \
	-c ./${Output}/SequenceCounts/16sHits.tsv \
	-o ${Figures}/16sHits.pdf \
	-t "Percent Reads Mapping to 16S"

