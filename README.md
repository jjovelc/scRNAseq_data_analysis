#  Single-Cell RNA-seq Data Analysis: A Conceptual and Practical Framework

This repo serves as a supplement of the publication with the title referenced above. Instead of providing full scripts, we present here snippets that guide the reader on how to conduct specific tasks described in the publication.

Unless otherwise indicated, all examples presented hereafter are based on the 10X genomics dataset derived using the Single Cell 3' v3 chemistry named Parent_NGSC3_DI_PBMC. The dataset is described [here](https://cf.10xgenomics.com/samples/cell-exp/4.0.0/Parent_NGSC3_DI_PBMC/Parent_NGSC3_DI_PBMC_web_summary.html). 

## Quantification

Although several methods can be used for quantification, we recommend using Salmon Alevin because it is easy to install and to use. 

__Snippet 1.__ Code for creating the Salmon index and quantification.

```bash
#!/bin/bash

# Grab today's date
DATE=$(date +%Y-%m-%d)
SUFFIX="_PBMC_R1.fq.gz"

##########
# STEP 1: Generate a transcript-to-gene mapping file
# The `make_t2g.py` script is used to create this file.

TRANSCRIPTOME="Homo_sapiens.GRCh38.cdna.all.fa"

# Check if the transcriptome file exists
if [[ ! -f "$TRANSCRIPTOME" ]]; then
  echo "Error: Transcriptome file $TRANSCRIPTOME not found."
  exit 1
fi

grep ">" "$TRANSCRIPTOME" | python make_t2g.py > t2g.txt
echo "Transcript-to-gene mapping file created: t2g.txt"

##########
# STEP 2: Index the reference transcriptome
# Salmon requires an index to be generated from the transcriptome.

TRANSCRIPTOME_IDX="${TRANSCRIPTOME/.fa/.idx}"

salmon index -t "$TRANSCRIPTOME" -i "$TRANSCRIPTOME_IDX"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to generate Salmon index."
  exit 1
fi
echo "Salmon index created at $TRANSCRIPTOME_IDX"

##########
# STEP 3: Quantify libraries with Salmon Alevin
# This section processes multiple FASTQ files (or a single pair).

# Ensure the directory containing FASTQ files is defined
DIR="./fastq_files"  # Replace with your FASTQ directory
if [[ ! -d "$DIR" ]]; then
  echo "Error: Directory $DIR not found."
  exit 1
fi

# Construct the lists of barcode and read files
BARCODES_FILES=()
READS_FILES=()
for BARCODES in "$DIR"/*"$SUFFIX"; do
  if [[ -f "$BARCODES" ]]; then
    BARCODES_FILES+=("$BARCODES")
    READS="${BARCODES/R1/R2}"  # Replace R1 with R2 for paired-end reads
    READS_FILES+=("$READS")
  else
    echo "Warning: No files matching $SUFFIX found in $DIR."
  fi
done

# Ensure there are files to process
if [[ ${#BARCODES_FILES[@]} -eq 0 ]]; then
  echo "Error: No FASTQ files found for processing."
  exit 1
fi

# Run Salmon Alevin for each pair of FASTQ files
TGMAP="t2g.txt"  # Path to the transcript-to-gene mapping file
for i in "${!BARCODES_FILES[@]}"; do
  OUTPUT_DIR="alevin_output_${DATE}_${i}"
  salmon alevin -l ISR \
      -i "$TRANSCRIPTOME_IDX" \
      -1 "${BARCODES_FILES[$i]}" \
      -2 "${READS_FILES[$i]}" \
      -o "$OUTPUT_DIR" \
      --tgMap "$TGMAP" \
      --dumpFeatures \
      --dumpUmiGraph \
      --chromium \
      --dumpMtx \
      -p 8

  if [[ $? -ne 0 ]]; then
    echo "Error: Salmon Alevin failed for ${BARCODES_FILES[$i]} and ${READS_FILES[$i]}"
    exit 1
  fi
  echo "Processed: ${BARCODES_FILES[$i]} and ${READS_FILES[$i]}"
  echo "Output directory: $OUTPUT_DIR"
done

echo "Salmon Alevin processing completed for all libraries."

# Note:
# The flag `--chromium` must be adjusted if libraries were not generated
# using 10X Genomics v3 chemistry.
```

