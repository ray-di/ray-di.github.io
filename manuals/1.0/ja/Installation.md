---
layout: docs-ja
title: インストール
category: Manual
permalink: /manuals/1.0/ja/installation.html
---
# Installation

Ray.Diのインストールは、[Composer](https://github.com/composer/composer)から行います

```bash
composer require ray/di ^2.0
```

GitHubのリポジトリは[ray-di/Ray.Di](https://github.com/ray-di/Ray.Di)です。

## Testing Ray.Di

Ray.Diをソースからインストールし、ユニットテストとデモを実行する方法を説明します。

```bash
git clone https://github.com/ray-di/Ray.Di.git
cd Ray.Di
./vendor/bin/phpunit
php demo-php8/run.php
```
