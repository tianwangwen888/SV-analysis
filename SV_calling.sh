#!/bin/bash
#PBS -N SV_Calling
#PBS -l nodes=1:ppn=1
#PBS -l walltime=1000:00:00
#PBS -q batch
#PBS -V

echo "Start at:"
date
cd /public/home/twwen/raw_cultivar_seq/Gh_ref_bam

module load lumpy/0.2.13
module load BCFtools/1.3-foss-2016b
module load Java/1.8.0_92
module load GATK/3.6-Java-1.8.0_92
module load SAMtools/1.3-foss-2016b

cat ID |while read line
do
echo ${line}
bwa mem -M -t 10  TM1_HZAU.fa ${line}_1.fastq.gz ${line}_2.fastq.gz >${line}.sam
java -Xmx20g -jar SortSam.jar INPUT=${line}.sam OUTPUT=${line}_srt.bam VALIDATION_STRINGENCY=LENIENT CREATE_INDEX=TRUE SORT_ORDER=coordinate
java -Xmx20g -jar FixMateInformation.jar INPUT=${line}_srt.bam OUTPUT=${line}_fxmt.bam SO=coordinate VALIDATION_STRINGENCY=LENIENT CREATE_INDEX=TRUE
java -Xmx20g -jar MarkDuplicates.jar INPUT=${line}_fxmt.bam OUTPUT=${line}_mkdup.bam METRICS_FILE=${line}.metrics VALIDATION_STRINGENCY=LENIENT CREATE_INDEX=TRUE MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000
java -Xmx20g -jar AddOrReplaceReadGroups.jar INPUT=${line}_mkdup.bam OUTPUT=${line}.addrep.bam RGID=${line} PL=Illumina SM=${line} CN=BGI VALIDATION_STRINGENCY=LENIENT SO=coordinate CREATE_INDEX=TRUE RGLB=${line} RGPU=${line} 
java -Xmx20g -jar $EBROOTGATK/GenomeAnalysisTK.jar -T RealignerTargetCreator -R TM1_HZAU.fa -I ${line}.addrep.bam -o ${line}.intervals -nt 10
java -Xmx20g -jar $EBROOTGATK/GenomeAnalysisTK.jar -T IndelRealigner -R TM1_HZAU.fa -I ${line}.addrep.bam -targetIntervals ${line}.intervals -o ${line}_realn.bam 
java -Xmx20g -jar $EBROOTGATK/GenomeAnalysisTK.jar -T UnifiedGenotyper -R TM1_HZAU.fa -nt 10 -stand_call_conf 50.0 -stand_emit_conf 30.0 -dcov 200 -glm BOTH  -I ${line}_realn.bam -o ${line}_GATK.vcf
samtools view -b -F 1294 ${line}_realn.bam >  ${line}.discordants.unsorted.bam
samtools view -h ${line}_realn.bam | ~/software/extractSplitReads_BwaMem -i stdin | samtools view -Sb - > ${line}.splitters.unsorted.bam
samtools sort ${line}.discordants.unsorted.bam >${line}.discordants
samtools sort ${line}.splitters.unsorted.bam >${line}.splitters
lumpyexpress -B ${line}_realn.bam -S ${line}.splitters -D ${line}.discordants -o ${line}.vcf
done
echo "End at:"
date
