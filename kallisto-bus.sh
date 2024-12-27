#!/usr/bin/env bash

# Ensure script exits on any error
set -e

# Activate conda environment
eval "$(conda shell.bash hook)"
conda activate kallisto_bus

KALLISTO=$(which kallisto) 
BUSTOOLS=$(which bustools) 
INDEX="hsapiens_kb_index.idx" 
T2G="hsapiens_kb_t2g.txt"  
WHITELIST="10xv3_whitelist.txt" 
FASTQ_R1="Parent_NGSC3_DI_PBMC_R1.fq.gz"
FASTQ_R2="Parent_NGSC3_DI_PBMC_R2.fq.gz"
OUTPUT_DIR="kb_out_h5ad"
THREADS=24

# output directory
mkdir -p "$OUTPUT_DIR"

# Run Kallisto BUS to process reads
$KALLISTO bus -i "$INDEX" -x 10xv3 -o "$OUTPUT_DIR" -t "$THREADS" "$FASTQ_R1" "$FASTQ_R2"

# Correct barcodes using Bustools
$BUSTOOLS correct \
    -w "$WHITELIST" \
    -o "$OUTPUT_DIR/corrected.bus" \
    "$OUTPUT_DIR/output.bus"

# Sort the corrected BUS file
$BUSTOOLS sort \
    -t "$THREADS" \
    -o "$OUTPUT_DIR/sorted.bus" \
    "$OUTPUT_DIR/corrected.bus"

# Generate gene-cell count matrix
$BUSTOOLS count \
    -o "$OUTPUT_DIR/counts" \
    -g "$T2G" \
    -e "$OUTPUT_DIR/matrix.ec" \
    -t "$OUTPUT_DIR/matrix.tx" \
    "$OUTPUT_DIR/sorted.bus"

echo "Kallisto BUS processing completed. Results saved to $OUTPUT_DIR."

# Optional: print summary of output files
echo "Output files:"
ls -l "$OUTPUT_DIR"
