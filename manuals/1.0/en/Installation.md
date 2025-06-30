1---
layout: docs-en
title: Installation
category: Manual
permalink: /manuals/1.0/en/installation.html
---
# Installation

The recommended way to install Ray.Di is through [Composer](https://github.com/composer/composer).

```bash
composer require ray/di ^2.0
```

The GitHub repository is at [ray-di/Ray.Di](https://github.com/ray-di/Ray.Di)

## Testing Ray.Di

Here's how to install Ray.Di from source and run the unit tests and demos.

```bash
git clone https://github.com/ray-di/Ray.Di.git
cd Ray.Di
./vendor/bin/phpunit
php demo-php8/run.php
```
