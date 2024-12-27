import sys

# USAGE:
# Run this script by piping the output of `grep ">" file.fasta` to the script, specifying the output file.
# Example:
# grep ">" file.fasta | python generate_t2g_file_from_headers.py <output.txt>
#
# Description:
# This script reads transcript headers from stdin (filtered lines starting with '>' from a FASTA file).
# It extracts the transcript ID and either the gene symbol or gene ID, then writes these to the stdout.

# Read from stdin (the piped output from grep)
for line in sys.stdin:
    if line.startswith('>'):
        # Remove the '>' at the beginning and strip any leading/trailing whitespace
        line_content = line[1:].strip()
        # Split the line into fields
        fields = line_content.split()
        # The first field is the transcript ID
        transcript_id = fields[0]
        # Initialize variables
        gene_symbol = None
        gene_id = None
        # Iterate over the fields to find 'gene_symbol' and 'gene'
        for field in fields:
            if field.startswith('gene_symbol:'):
                # Extract the gene symbol
                gene_symbol = field.split('gene_symbol:')[1]
            elif field.startswith('gene:'):
                # Extract the gene ID
                gene_id = field.split('gene:')[1]
        # Determine the second column value
        if gene_symbol:
            second_column = gene_symbol
        else:
            second_column = gene_id
        # Write the output to the file
        print(f'{transcript_id}\t{second_column}')
