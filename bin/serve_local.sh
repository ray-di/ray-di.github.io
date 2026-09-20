#!/bin/bash
set -euo pipefail
trap 'echo "serve_local.sh failed; check generate_llms_full.php, copy_markdown_files.sh, or Jekyll output above." >&2' ERR

# This script is used to serve the Jekyll site locally with automatic rebuilding.
# 'bundle exec' ensures we're using the correct versions of each gem according to our Gemfile.lock.
# 'jekyll serve' starts a Jekyll development server.
# '--watch' option automatically rebuilds the site when files are modified.

# Build the site once, then generate the Pagefind search index so the
# in-page search works locally. Jekyll keeps pre-existing static files in
# _site during watch rebuilds (see keep_files in _config.yml), so the index
# survives subsequent edits. Skip silently if npx/pagefind is unavailable.
echo "Building site and generating search index..."
php bin/generate_llms_full.php
bundle exec jekyll build
./bin/copy_markdown_files.sh
if command -v npx >/dev/null 2>&1; then
  npx --yes pagefind@latest --site _site || echo "Warning: pagefind index generation failed; search disabled."
else
  echo "Note: npx not found; skipping Pagefind search index."
fi

bundle exec jekyll serve --watch
