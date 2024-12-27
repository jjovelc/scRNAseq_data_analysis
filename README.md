#  Single-Cell RNA-seq Data Analysis: A Conceptual and Practical Framework

This repo serves as a supplement of the publication with the title referenced above. Instead of providing full scripts, we present here snippets that guide the reader on how to conduct specific tasks described in the publication.

Unless otherwise indicated, all examples presented hereafter are based on the 10X genomics dataset derived using the Single Cell 3' v3 chemistry named Parent_NGSC3_DI_PBMC. The dataset is described [here](https://cf.10xgenomics.com/samples/cell-exp/4.0.0/Parent_NGSC3_DI_PBMC/Parent_NGSC3_DI_PBMC_web_summary.html). 

## Quantification

Although several methods can be used for quantification, we recommend using Salmon Alevin because it is easy to install and to use. 

__Snippet 1.__ Code for creating the Salmon index and quantification.

```bash
  ##########
  # STEP 1. Generate a transcript-to-gene mapping file
  # we provide script make_t2g.py script to help with this.

  TRANSCRIPTOME="Homo_sapiens.GRCh38.cdna.all.fa"
  
  grep ">" "$TRANSCRIPTOME" | python make_t2g.py > t2g.txt

  ##########
  # STEP 2. The reference transcriptome is then indexed
  # in the canonical way needed for Salmon

  INDEXFILE="${TRANSCRIPTOME/.fa/idx"

  salmon index -t "$TRANSCRIPTOME"  -i "$INDEXFILE"

  ##########
  # STEP 3. Quantify libraries with Salmon Alevin

  # The code is designed to process multiple FASTQ files
  # but it should equally work with a single pair of files

  # Construct the lists of barcode and read files
  BARCODES_FILES=()
  READS_FILES=()
  # Adjust suffix if needed (_PBMC_R1.fq.gz)
  for BARCODES in ${DIR}/*_PBMC_R1.fq.gz; do
      BARCODES_FILES+=("$BARCODES")
      READS="${BARCODES%_R1.fq.gz}_R2.fq.gz"
      READS_FILES+=("$READS")
  done

  # Run Salmon Alevin for each pair
  for i in "${!BARCODES_FILES[@]}"; do
      OUTPUT_DIR="${HOME}/alevin_output_241020_PBMC4k_${i}"

      singularity exec --bind "${DIR}:${DIR}" "${DIR}/${SIF}" salmon alevin -l ISR \
          -i "${TRANSCRIPTOME_IDX}" \
          -1 "${BARCODES_FILES[$i]}" \
          -2 "${READS_FILES[$i]}" \
          -o "${OUTPUT_DIR}" \
          --tgMap "${TGMAP}" \
          --dumpFeatures \
          --dumpUmiGraph \
          --chromium \
          --dumpMtx \
          -p 24
  done

```
