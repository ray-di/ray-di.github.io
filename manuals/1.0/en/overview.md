---
layout: docs-en
title: Overview
category: Manual
permalink: /manuals/1.0/en/index.html
---
# Overview

There are many advantages to using dependency injection, but doing so manually often leads to a large amount of boilerplate code to be written. Ray.Di is a framework that makes it possible to write code that uses dependency injection without the hassle of writing much of that boilerplate code,as further detailed in this page on [Motivation](motivation.html).

Put simply, Ray.Di alleviates the need for factories and the use of `new` in your PHP code. You will still need to write factories in some cases, but your code will not depend directly on them. Your code will be easier to change, unit test and reuse in other contexts.

## Google Guice and Ray.Di

Ray.Di is a PHP DI framework inspired by [Google Guice](https://github.com/google/guice). Most of the documentation on this site is taken from Google Guice.
