#!/bin/bash
set -euo pipefail

# Build the Jekyll site
bundle exec jekyll build

# Copy markdown files for llms.txt compliance
./bin/copy_markdown_files.sh

# Start Jekyll server with watch mode
bundle exec jekyll serve --host 0.0.0.0 --watch