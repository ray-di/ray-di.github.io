# Ray.Di Documentation Build Scripts

This directory contains utility scripts for building, serving, and managing the Ray.Di documentation website.

## Scripts Overview

### Development Scripts

#### `serve_local.sh`
Serves the Jekyll site locally with automatic rebuilding and llms.txt compliance.

```bash
./bin/serve_local.sh
```

**What it does:**
- Builds the Jekyll site with `bundle exec jekyll build`
- Copies markdown files for llms.txt standard compliance
- Starts Jekyll development server with `--watch` mode
- Accessible at http://localhost:4000

**Prerequisites:**
- Ruby 3.2.x
- Bundler installed (`gem install bundler`)
- Dependencies installed (`bundle install`)

#### `serve_docker.sh`
Serves the Jekyll site using Docker Compose.

```bash
./bin/serve_docker.sh
```

**What it does:**
- Starts Docker container with Jekyll environment
- Accessible at http://localhost:4000

**Prerequisites:**
- Docker and Docker Compose installed

### Build Scripts

#### `entrypoint.sh`
Docker entrypoint script that builds and serves the site.

```bash
./bin/entrypoint.sh
```

**What it does:**
- Builds the Jekyll site
- Copies markdown files for llms.txt compliance
- Starts Jekyll server with host 0.0.0.0 for container access

### Documentation Scripts

#### `copy_markdown_files.sh`
Copies markdown files to `_site` directory for llms.txt standard compliance.

```bash
./bin/copy_markdown_files.sh
```

**What it does:**
- Copies all `.md` files from `manuals/` to `_site/manuals/`
- Removes Jekyll front matter from copied files
- Enables AI assistants to access clean markdown content
- Supports llms.txt standard for AI-accessible documentation

## GitHub Actions Integration

The following scripts are suitable for GitHub Actions automation:

### Recommended GitHub Actions

#### 1. Documentation Build and Deploy
```yaml
name: Build and Deploy Documentation
on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2
        bundler-cache: true
    - name: Build Jekyll site
      run: |
        bundle exec jekyll build
        ./bin/copy_markdown_files.sh
    - name: Deploy to GitHub Pages
      uses: actions/deploy-pages@v3
      with:
        path: _site
```

#### 2. Documentation Validation
```yaml
name: Validate Documentation
on:
  pull_request:
    paths:
    - 'manuals/**'
    - 'llms.txt'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2
        bundler-cache: true
    - name: Check for broken links
      run: |
        bundle exec jekyll build
        # Add link checking tool here
```

## llms.txt Standard Compliance

This documentation follows the [llms.txt standard](https://llms-txt.org/) for AI-accessible documentation:

- **`llms.txt`**: Index file with links to all documentation
- **`llms-full.txt`**: Hand-authored single-file LLM reference (edit it directly; it is not generated)
- **Raw markdown files**: Available at `/manuals/1.0/{lang}/{file}.md` URLs
- **Human-readable HTML**: Available at `/manuals/1.0/{lang}/{file}.html` URLs

## Dependencies

- **Ruby**: 3.2.x (for Jekyll and Ruby scripts)
- **Bundler**: For Ruby gem management
- **Docker**: Optional, for containerized development

## Usage Examples

### Local Development
```bash
# Start local development server
./bin/serve_local.sh

# Or with Docker
./bin/serve_docker.sh
```

### Production Build
```bash
# Build for production
bundle exec jekyll build
./bin/copy_markdown_files.sh
```

## File Structure

```
bin/
├── README.md                 # This file
├── serve_local.sh            # Local development server
├── serve_docker.sh           # Docker development server
├── entrypoint.sh             # Docker entrypoint
└── copy_markdown_files.sh    # Copy markdown for llms.txt compliance
```

## Contributing

When adding new scripts:

1. Make scripts executable: `chmod +x bin/script_name.sh`
2. Add appropriate error handling with `set -euo pipefail` for bash scripts
3. Include clear documentation in this README
4. Consider GitHub Actions integration for automation opportunities
5. Follow existing naming conventions and coding standards
