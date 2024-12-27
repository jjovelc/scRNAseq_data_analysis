#!/usr/bin/bash

cellranger count --id=run_count_1kpbmcs \
   --fastqs=/work/vetmed_data/jj/projects/jeffBiernaski/reindeer/genomes/cellRanger_tutorials/count_tutorial/pbmc_1k_v3_fastqs\
   --sample=pbmc_1k_v3 \
   --transcriptome=/work/vetmed_data/jj/projects/jeffBiernaski/reindeer/genomes/cellRanger_tutorials/count_tutorial/refdata-gex-GRCh38-2020-A

