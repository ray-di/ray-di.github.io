---
layout: docs-ja
title: Overview
category: Manual
permalink: /manuals/1.0/ja/index.html
---
# 概要

依存性注入（ディペンデンシーインジェクション）には多くの利点がありますが、手作業でそれを行うと、しばしば大量の定型的なコードを書かなければならなくなります。Ray.Diは、[モチベーション](motivation.html)のページで詳しく説明されているように、面倒な定型文を書かずに依存性注入を使用したコードを書くことを可能にするためのフレームワークです。

簡単に言うと、Ray.DiはファクトリーやPHPコードでの`new`の使用を不要にするものです。ファクトリーを書く必要がある場合もありますが、コードが直接ファクトリーに依存することはありません。あなたのコードは、変更、ユニットテスト、他の文脈での再利用がより簡単になります。

## Google GuiceとRay.Di

Ray.Diは[Google Guice](https://github.com/google/guice)にインスパイアされたPHPのDIフレームワークです。このサイトのほとんどのドキュメントはGoogle Guiceから引用しています。
