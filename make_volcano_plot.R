
# Load necessary libraries
library(ggplot2)
library(dplyr)
library(ggrepel) # For improved label placement

setwd('/Users/juanjovel/Library/CloudStorage/OneDrive-UniversityofCalgary/jj/UofC/data_analysis/me/courses/2024/scRNAseq/working_version')

# Load your data
data <- read.table("all_results_wilcox.tsv", header = TRUE, sep = "\t")

# Add a column to classify genes as upregulated, downregulated, or not significant
data <- data %>%
  mutate(
    gene_status = case_when(
      p_val_adj < 0.05 & avg_log2FC > 0.25 ~ "Upregulated",
      p_val_adj < 0.05 & avg_log2FC < -0.25 ~ "Downregulated",
      TRUE ~ "Not Significant"
    ),
    gene_label = ifelse(gene_status != "Not Significant", gene_symbol, NA) # Label only significant genes
  )

# Create the volcano plot
volcano_plot <- ggplot(data, aes(x = avg_log2FC, y = -log10(p_val_adj), color = gene_status)) +
  geom_point(alpha = 0.8, size = 3) + # Plot the points
  scale_color_manual(
    values = c(
      "Upregulated" = "firebrick4",
      "Downregulated" = "dodgerblue1",
      "Not Significant" = "darkgray"
    )
  ) + # Custom colors
  ylim(0, 20) + 
  theme_bw() + 
  labs(
    title = "Volcano Plot: Microglia COVID vs Control",
    x = "Average Log2 Fold Change (avg_log2FC)",
    y = "-Log10 Adjusted P-Value",
    color = "Gene Status"
  ) +
  geom_hline(yintercept = c(-log10(0.05), 50), linetype = "dashed", color = "red") + # P-value and horizontal lines
  geom_vline(xintercept = c(-0.4, 0.4), linetype = "dashed", color = "darkgreen") + # Updated vertical lines
  theme(
    plot.title = element_text(hjust = 0.5, size = 16),
    axis.title = element_text(size = 14),
    axis.text = element_text(size = 12),
    legend.position = "top"
  ) +
  geom_text_repel(aes(label = gene_label), max.overlaps = 10, size = 3, box.padding = 0.3) # Label significant genes

# Save the plot
ggsave("volcano_plot_COVID.png", plot = volcano_plot, width = 8, height = 6, dpi=300)

# Print the plot
print(volcano_plot)

