# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Jekyll-based documentation website for Ray.Di, a PHP dependency injection framework inspired by Google Guice. The site is hosted at https://ray-di.github.io/ and serves comprehensive documentation in both English and Japanese.

## Development Commands

### Local Development with Docker (Recommended)
```bash
./bin/serve_docker.sh
```
This starts a Docker container with Jekyll server accessible at http://localhost:4000

### Local Development with Ruby
Prerequisites: Ruby 3.2.3 (not later versions)
```bash
# Install dependencies
gem install jekyll bundler
bundle install

# Start development server
./bin/serve_local.sh
```
The development server runs with `--watch` for automatic rebuilding.

### Building the Site
Jekyll automatically builds the site when serving. The built site is output to `_site/`.

### Combining Manual Pages
```bash
ruby bin/merge_md_files.rb
```
This script combines all manual markdown files into single-page versions for both languages.

### Generating Comprehensive AI Documentation
```bash
php bin/generate_llms_full.php
```
This script generates `llms-full.txt` by expanding linked markdown files from `llms.txt` for comprehensive AI assistant documentation.

## Site Architecture

### Directory Structure
- `manuals/1.0/en/` - English documentation markdown files
- `manuals/1.0/ja/` - Japanese documentation markdown files
- `_layouts/` - Jekyll layout templates
  - `docs-en.html` - English documentation layout
  - `docs-ja.html` - Japanese documentation layout
  - `index.html` - Homepage layout
- `_includes/manuals/1.0/` - Reusable template components
- `_site/` - Generated static site (ignored in git)
- `css/` - Stylesheets
- `js/` - JavaScript files
- `images/` - Static assets

### Content Management
- Documentation files use Jekyll front matter with layout, title, category, and permalink
- English files use `layout: docs-en`, Japanese files use `layout: docs-ja`
- Permalinks follow pattern `/manuals/1.0/{lang}/{filename}.html`
- The site automatically detects browser language and redirects to appropriate locale

### Special Features
- `llms-full.txt` - Comprehensive Ray.Di documentation for AI assistants (based on llms.txt standard)
- AI Assistant page (`ai-assistant.md`) provides instructions for using Ray.Di with various AI tools
- **llms.txt Standard Compliance**: Markdown files are directly accessible for AI consumption
- Responsive design with Bootstrap and custom CSS
- Table of contents generation for documentation pages

## Development Notes

### Jekyll Configuration
- Uses Kramdown markdown processor with Rouge syntax highlighter
- Configured for GitHub Pages compatibility
- Development server runs on port 4000

### File Naming Convention
- Documentation files use descriptive names without numeric prefixes (e.g., `installation.md`, `motivation.md`)
- Files are ordered explicitly in `bin/merge_md_files.rb` for generating combined pages
- Best practices files in `bp/` subdirectory use descriptive hyphenated names

### Docker Setup
- Uses Ruby 3.2 base image
- Installs build-essential and libffi-dev for native gem compilation
- Serves on all interfaces (0.0.0.0) for container access

### Multilingual Support
- Duplicate content structure for English and Japanese
- JavaScript-based locale detection for homepage
- Shared layout templates with language-specific includes

### llms.txt Standard Implementation
- Markdown files are manually copied to `_site` directory for direct access
- The `bin/copy_markdown_files.sh` script copies all markdown files after Jekyll build
- Development scripts (`serve_local.sh` and Docker) automatically run the copy script
- URLs follow pattern: `/manuals/1.0/{lang}/{filename}.md` (AI-accessible) and `/manuals/1.0/{lang}/{filename}.html` (human-readable)
- Supports llms.txt standard for AI assistants to access clean markdown content
- `llms-full.txt` provides comprehensive framework documentation for AI consumption

### PHP Dependencies
The project includes Ray.Di framework as a Composer dependency for documentation examples and AI documentation generation:
```bash
composer install  # Install Ray.Di framework dependency
```

### Manual Build Process
If building manually without the scripts:
```bash
bundle exec jekyll build
./bin/copy_markdown_files.sh
```