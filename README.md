# Single-Cell RNA-seq Data Analysis: A Conceptual and Practical Framework

This repo serves as a supplement of the publication with the title referenced above. Instead of providing full scripts, we present here snippets that guide the reader on how to conduct specific tasks described in the publication.

Because of their popularity, we provide code using the frameworks Seurat (for R users) and Scanpy (for Python users), whenever we manage to get a working version of the code.

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

__Snippet 2.__ R Code to run QC analysis of the Alevin quentification.

```R
library(alevinQC)

### Set the working directory
working_dir <- '/your/directory/'

setwd(working_dir)
dir <- getwd()

alevinQCReport(baseDir = dir,               # Directory containing folder alevin
               sampleId = "pbmc4k",         # Add any sample name you like
               outputFile = "alevinReport.html",   # Name of the output file
               outputFormat = "html_document",     # Format of the output file
               outputDir = dir,                    # Directory where you want to save the report
               forceOverwrite = TRUE)
```

__Snippet 3.__ R code to import Salmon Alevin quantification matrix.

```R
library(tximport)

# Set working directory
setwd('/your/directory/')

# Define the path to the Alevin output directory
alevin_dir <- "alevin" # The alevin directory generated by Salmon Alevin

# Define file paths for tximport
files <- file.path(alevin_dir, "quants_mat.gz")
names(files) <- "pbmc4k"

# Check if the files exist before importing with tximport
if (all(file.exists(files))) {
  txi <- tximport(files, type = "alevin")
  print("Import successful.")
} else {
  stop("Error: One or more files do not exist at the specified path.")
}

data <- txi$counts

```

__Snippet 4.__ Python (Scanpy) code to import Salmon Alevin quantification matrix.

```python
# Set the working directory
working_dir = "/directory/alevin/" # Set properly
os.chdir(working_dir)

# Define data path
matrix_file = os.path.join(working_dir, "quants_mat.mtx.gz")
genes_file = os.path.join(working_dir, "quants_mat_cols.txt")  # This has genes
barcodes_file = os.path.join(working_dir, "quants_mat_rows.txt")  # This has barcodes

# Check if all required files exist
if all(os.path.exists(f) for f in [matrix_file, genes_file, barcodes_file]):
    print("All files exist. Proceeding with import...")
    
    # Read the sparse matrix (MTX format)
    with gzip.open(matrix_file, "rt") as f:
        matrix = mmread(f)
    
    # Convert to CSR format without transposing
    matrix = csr_matrix(matrix)
    
    # Read genes and barcodes
    genes = pd.read_csv(genes_file, header=None, sep="\t")[0].values
    barcodes = pd.read_csv(barcodes_file, header=None, sep="\t")[0].values
    
    # Create an AnnData object
    adata = ad.AnnData(X=matrix)
    adata.obs_names = barcodes  # Set barcodes first
    adata.var_names = genes  # Set genes second
    
    print("Import successful.")
    print(f"Matrix shape: {adata.shape}")
    
    # Verify the structure
    print("\nFirst few gene names:")
    print(adata.var_names[:5])
    print("\nFirst few cell barcodes:")
    print(adata.obs_names[:5])
else:
    raise FileNotFoundError("One or more required files are missing. Please check your directory.")
```

__Snippet 5.__ Quality inspection using Seurat in R.

```R
# Create the Seurat object
object <- CreateSeuratObject(counts = data, project = "pbmc4k")

### QC ###
object[["percent.mt"]] <- PercentageFeatureSet(object, pattern = "^MT-")

# QC metrics can be visualized in a violin plot
VlnPlot(object, features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3, cols='dodgerblue')

# FeatureScatter is typically used to visualize feature-feature relationships
plot1 <- FeatureScatter(object, feature1 = "nCount_RNA", feature2 = "percent.mt", col='pink1')
plot2 <- FeatureScatter(object, feature1 = "nCount_RNA", feature2 = "nFeature_RNA", col='darkturquoise')
plot1 + plot2
```

__Snippet 6.__ Quality inspection using Scanpy in Python.

```Python
# This assumes data is already in object adata as explained 
# in Snippet 4.

# Verify uniqueness in dataset
n_duplicates = sum(adata.obs_names.duplicated())

if n_duplicates > 0:
    print(f"Warning: {n_duplicates} duplicate observations found in combined dataset")
    adata.obs_names_make_unique()

# Determine some QC parameters
# mitochondrial genes, "MT-" for human, "Mt-" for mouse
# Adjust mitochondrial gene identification for mouse data
adata.var["mt"] = adata.var_names.str.startswith(("MT-"))

# ribosomal genes
adata.var["ribo"] = adata.var_names.str.startswith(("RPS", "RPL"))

sc.pp.calculate_qc_metrics(
adata, qc_vars=["mt", "ribo"], inplace=True, log1p=True
)

output_file = "_plot_beforeFiltering.png"
sc.pl.violin(
    adata,
    ["n_genes_by_counts", "total_counts", "pct_counts_mt"],
    jitter=0.4,
    color="violet",
    size=2,
    multi_panel=True,
    save=output_file
  
)

```

__Snippet 7.__ R code to filter cells according to number of genes, total RNA and percent mt.

```R
# Filter
object <- subset(object, subset = nFeature_RNA > 200 & 
                 nFeature_RNA < 6000 & 
                 percent.mt < 5 &
                 nCount_RNA < 25000)

```

__Snippet 8.__ Python code to filter cells according to number of genes, total RNA and percent mt.

```Python
# Filter data according to QC metrics

adata = adata[
    (adata.obs["pct_counts_mt"] < 5) &
    (adata.obs["n_genes_by_counts"] < 6000) &
    (adata.obs["n_genes_by_counts"] > 200) &
    (adata.obs["total_counts"] < 25000)
]
```

__Snippet 9.__ R code to detect and remove doublets.

```R
# Doublet diagnostics
# propose the number of doublets to find
# For 10X v3 chemistry 7.5% is appropriate
nExp_poi <- round(0.075 * ncol(object))

# Run DoubletFinder
object <- doubletFinder(object, PCs = 1:30, pN = 0.25, pK = 0.09, nExp = nExp_poi)

# Subset the Seurat object to exclude doublets
# Explore Seurat object to find out the exact 
# DF.classifications name, in this case
# DF.classifications_0.25_0.09_132
object <- subset(object, subset = DF.classifications_0.25_0.09_132 == "Singlet")

# Verify the result
table(pbmc@meta.data$DF.classifications_0.25_0.09_132)

```

__Snippet 10.__ Python code to detect and remove doublets.

```Python
# Detect doublets
# Doublet detection using Scrublet
adata.layers["counts"] = adata.X.copy()  # Save count data before normalization

# If the data is in sparse format, convert it to a dense matrix
counts_matrix = adata.X.toarray() if scipy.sparse.issparse(adata.X) else adata.X

# Initialize Scrublet
scrub = scr.Scrublet(counts_matrix)

# Run Scrublet
doublet_scores, predicted_doublets = scrub.scrub_doublets()

# Plot doublets results
# Add the results back to the AnnData object
adata.obs["doublet_scores"] = doublet_scores
adata.obs["predicted_doublets"] = predicted_doublets.astype(str)  # Ensure boolean values are converted to strings for visualization

adata = adata[adata.obs["predicted_doublets"] == "False", :]
```

__Snippet 11.__ Data preprocessing in Seurat (R).

```R
# Normalize
object <- NormalizeData(object, normalization.method = "LogNormalize", scale.factor = 10000)

# Find variable features (genes that explain most of the variance)
object <- FindVariableFeatures(object, selection.method = "vst", nfeatures = 2000)

# Scale data
# It initially divides the expression of each gene by its standard deviation (z-score)
# For centering the data, the mean expression is substracted so that the data is centered
# around zero
object <- ScaleData(object, features = all.genes)

# Run PCA analysis
object <- RunPCA(object, features = VariableFeatures(object = object))

# Determine the ‘dimensionality’ of the dataset by elbor plot
ElbowPlot(object)

# Produce PC loadings plot
VizDimLoadings(pbmc, dims = 1:2, reduction = "pca")
```

__Snippet 12.__ Data preprocessing in Scanpy (Python).

```Python
# Preserve raw data for DE analysis
adata.raw = adata.copy()

# Normalizing to median total counts
sc.pp.normalize_total(adata, target_sum=1e4)

# Logarithmize the data
sc.pp.log1p(adata)

# Feature selection (highly variable genes)
sc.pp.highly_variable_genes(adata, n_top_genes=2000)
sc.pl.highly_variable_genes(adata)

# Run PCA and produce weights plot
sc.tl.pca(adata)
# Elbow plot
output_file = "_elbow_plot.png"
sc.pl.pca_variance_ratio(
    adata,
    n_pcs=50,
    log=True,
    save=output_file)

# Produce PC loadings plot
sc.pl.pca_loadings(
    adata,
    components=[1, 2], 
    show=True  
)
```

__Snippet 13.__ Clustering of scRNAseq data using Seurat (R).

```R
# Find neighbors, using the first 10 PCs
object <- FindNeighbors(object, dims = 1:10)

# Conduct clustering. Leiden is implemented by default
# to use Louvain add parameter 'algorithm = 1'
object <- FindClusters(object, resolution = 0.8)

# Run tSNE
object <- RunTSNE(object, 
                dims = 1:10,
                perplexity = 30,    # default is 30
                max_iter = 1000,    # default is 1000
                theta = 0.5,        # learning rate, default is 0.5
                seed.use = 42       # for reproducibility
)

# Create tSNE plot
plot <- DimPlot(object, reduction = "tsne", label = TRUE)
print(plot)

# Run UMAP
object <- RunUMAP(object, dims = 1:10)

# Create UMAP plot
plot <- DimPlot(object, reduction = "umap", label = TRUE)
print(plot)
```

__Snippet 14.__ Clustering of scRNAseq data using Scanpy (Python).

```Python
# Use the first 10 PCs to compute the neighborhood graph
sc.pp.neighbors(adata, n_pcs=10)

# Perform clustering using the Leiden algorithm (default in Scanpy)
# To use Louvain, pass `method='louvain'` to `sc.tl.leiden`
sc.tl.leiden(adata, resolution=0.8)

# Run tSNE
sc.tl.tsne(adata, n_pcs=10, perplexity=30, use_rep='X_pca', random_state=42)

# Plot tSNE with cluster labels
sc.pl.tsne(adata, color='leiden', legend_loc='on data', save="_tsne_plot.png")

# Run UMAP
sc.tl.umap(adata)

# Plot UMAP with cluster labels
sc.pl.umap(adata, color='leiden', legend_loc='on data', save="_umap_plot.png")
```
