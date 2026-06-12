#!/bin/bash
set -euo pipefail
trap 'echo "serve_local.sh failed; check generate_llms_full.php, copy_markdown_files.sh, or Jekyll output above." >&2' ERR

# This script is used to serve the Jekyll site locally with automatic rebuilding.
# 'bundle exec' ensures we're using the correct versions of each gem according to our Gemfile.lock.
# 'jekyll serve' starts a Jekyll development server.
# '--watch' option automatically rebuilds the site when files are modified.

# Copy markdown files for llms.txt compliance after initial build
echo "Starting Jekyll server with llms.txt compliance..."
php bin/generate_llms_full.php
bundle exec jekyll build
./bin/copy_markdown_files.sh
bundle exec jekyll serve --watch
