#!/usr/bin/env bash

# Ensure script exits on any error
set -e

# Activate conda environment
eval "$(conda shell.bash hook)"
conda activate kallisto_bus

# Get the path to kallisto
KALLISTO_PATH=$(which kallisto)

# Define input files and parameters
INDEX="hsapiens_kb_index.idx"
T2G="hsapiens_kb_t2g.txt"
FASTQ_R1="Parent_NGSC3_DI_PBMC_R1.fq.gz"
FASTQ_R2="Parent_NGSC3_DI_PBMC_R2.fq.gz"
OUTPUT_DIR="kb_out_h5ad"

# Run kb count
kb count -i "$INDEX" -g "$T2G" -x 10xv3 --h5ad -t 24 \
    -o "$OUTPUT_DIR" \
    "$FASTQ_R1" "$FASTQ_R2" \
    --kallisto "$KALLISTO_PATH"

# Convert HDF5 to text (uncomment if needed)
# if command -v bustools &> /dev/null; then
#     bustools text "$OUTPUT_DIR/output.bus" > bus_output.txt
# else
#     echo "bustools is not installed or not in PATH. Please install it to convert HDF5 to text."
# fi

# Optional: print summary of output files
echo "Output files:"
ls -l "$OUTPUT_DIR"
