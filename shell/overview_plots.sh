#!/usr/bin/env bash

###############################
#    RAS Modifiers Project    #
###############################

# Copyright (c) 2022-Present Ryan L. Collins and the Van Allen/Gusev/Haigis Laboratories
# Distributed under terms of the GNU GPL v2.0 License (see LICENSE)
# Contact: Ryan L. Collins <Ryan_Collins@dfci.harvard.edu>

# Generate summary plots for cohorts, cancer types, and somatic/germline variants

# Note: intended to be executed on the MGB ERISOne cluster


### Set local parameters
export TCGADIR=/data/gusev/USERS/rlc47/TCGA
export PROFILEDIR=/data/gusev/USERS/rlc47/PROFILE
export WRKDIR=/data/gusev/USERS/rlc47/RAS_modifier_analysis
export CODEDIR=$WRKDIR/../code/ras_modifiers
cd $WRKDIR


### Set up directory trees as necessary
for SUBDIR in plots plots/overview data/plotting; do
  if ! [ -e $WRKDIR/$SUBDIR ]; then
    mkdir $WRKDIR/$SUBDIR
  fi
done


### Ensure most recent version of RASMod R package is installed from source
Rscript -e "install.packages('$CODEDIR/src/RASMod_0.1.tar.gz', \
                             lib='~/R/x86_64-pc-linux-gnu-library/3.6', \
                             type='source', repos=NULL)"


### Plot patient metadata summaries
$CODEDIR/scripts/plot/plot_pheno_summary.R \
  --cohort-name TCGA --metadata $TCGADIR/data/sample_info/TCGA.ALL.sample_metadata.tsv.gz \
  --cohort-name DFCI --metadata $PROFILEDIR/data/sample_info/PROFILE.ALL.sample_metadata.tsv.gz \
  --out-prefix $WRKDIR/plots/overview/cohort_summary


### Plot somatic variant summaries
# Collapse all variant frequencies for all cohorts
for cohort in TCGA PROFILE; do
  case $cohort in
    TCGA)
      cname=TCGA
      ;;
    PROFILE)
      cname=DFCI
      ;;
  esac
  for context in coding other; do
    zcat $WRKDIR/data/variant_set_freqs/$cohort.somatic.${context}_variants.freq.tsv.gz \
    | sed '1d' | awk -v OFS="\t" -v cohort=$cname '{ print cohort, $0 }'
  done
done \
| sort -Vk2,2 -k1,1V \
| cat <( zcat $WRKDIR/data/variant_set_freqs/TCGA.somatic.coding_variants.freq.tsv.gz \
         | head -n1 | awk -v OFS="\t" '{ print "cohort", $0 }' ) - \
| gzip -c \
> $TMPDIR/somatic_variant_freqs.tsv.gz
# Build simple table of variant coordinates for each cohort 
for cohort in TCGA PROFILE; do
  case $cohort in
    TCGA)
      COHORTDIR=$TCGADIR
      cname=TCGA
      ;;
    PROFILE)
      COHORTDIR=$PROFILEDIR
      cname=DFCI
      ;;
  esac
  bcftools query \
    -f '%ID\t%CHROM\t%POS\n' \
    --regions-file $CODEDIR/refs/RAS_loci.GRCh37.bed.gz \
    $COHORTDIR/data/$cohort.RAS_loci.anno.clean.vcf.gz \
  | awk -v OFS="\t" -v cohort=$cname '{ print cohort, $1, $2, $3 }'
done \
| sort -Vk3,3 -k4,4n -k1,1V \
| cat <( echo -e "cohort\tvid\tchrom\tpos" ) - \
| gzip -c \
> $TMPDIR/somatic_variant_coords.tsv.gz
# Collapse all variant sets across cohorts
for cohort in TCGA PROFILE; do
  case $cohort in
    TCGA)
      cname=TCGA
      ;;
    PROFILE)
      cname=DFCI
      ;;
  esac
  for context in collapsed_coding_csqs other_single_variants; do
    zcat $WRKDIR/data/variant_sets/$cohort.somatic.$context.tsv.gz | sed '1d'
  done | awk -v OFS="\t" -v cohort=$cname '{ print cohort, $1, $NF }'
done \
| sort -Vk2,2 -k1,1V \
| cat <( echo -e "cohort\tset_id\tvids" ) - \
| gzip -c \
> $TMPDIR/variant_set_map.tsv.gz
# Gather necessary plotting data into single file
$TMPDIR/gather_somatic_ras_data.py \
  --freqs $TMPDIR/somatic_variant_freqs.tsv.gz \
  --variant-coords $TMPDIR/somatic_variant_coords.tsv.gz \
  --variant-set-map $TMPDIR/variant_set_map.tsv.gz \
  --transcript-info $WRKDIR/../refs/gencode.v19.annotation.transcript_info.tsv.gz \
  --outfile $WRKDIR/data/plotting/ras_somatic_variants.tsv.gz
# Plot single-gene locus overview plots for each RAS gene
# TODO: implement this
# Scatterplots of inter-cohort somatic frequency correlations
# TODO: implement this

