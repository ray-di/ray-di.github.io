---
layout: docs-en
title: Multibindings
category: Manual
permalink: /manuals/1.0/en/multibindings.html
---
# Multibindings

_Overview of Multibinder, MapBinder

[Multibinder](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/Multibinder.html) is intended for plugin-type architectures.

## Multibinding

Using `Multibinder` to host plugins.

### Multibinder

Multibindings make it easy to support plugins in your application. Made popular
by [IDEs](http://www.eclipseplugincentral.com) and
[browsers](https://addons.mozilla.org/en-US/firefox/), this pattern exposes APIs
for extending the behaviour of an application.

Neither the plugin consumer nor the plugin author need write much setup code for
extensible applications with Ray.Di. Simply define an interface, bind
implementations, and inject sets of implementations! Any module can create a new
Multibinder to contribute bindings to a set of implementations. To illustrate,
we'll use plugins to summarize ugly URIs like `http://bit.ly/1mzgW1` into
something readable on Twitter.

First, we define an interface that plugin authors can implement. This is usually
an interface that lends itself to several implementations. For this example, we
would write a different implementation for each website that we could summarize.

```php
interface UriSummarizerInterface
{
    /**
     * Returns a short summary of the URI, or null if this summarizer doesn't
     * know how to summarize the URI.
     */
    public function summarize(URI $uri): string;
}
```

Next, we'll get our plugin authors to implement the interface. Here's an
implementation that shortens Flickr photo URLs:

```php
class FlickrPhotoSummarizer implements UriSummarizer
{
    public function __construct(
        private readonly PhotoPaternMatcherInterface $matcher
    ) {}

    public function summarize(URI $uri): ?string
    {
        $match = $this->matcher->match($uri);
        if (! $match) {
            return null;
        }
        $id = $this->matcher->group(1);
        $photo = Photo::loockup($id);

        return $photo->getTitle();
    }
  }
}
```

The plugin author registers their implementation using a multibinder. Some
plugins may bind multiple implementations, or implementations of several
extension-point interfaces.

```php
class FlickrPluginModule extends AbstractModule
{
    public function configure(): void 
    {
        $uriBinder = Multibinder::newInstance($this, UriSummarizerInterface::class);
        $uriBinder->add(FlickrPhotoSummarizer::class);

        // ...bind plugin dependencies, such as our Flickr API key
   }
}
```

Now we can consume the services exposed by our plugins. In this case, we're
summarizing tweets:

```php
class TweetPrettifier
{
    /**
     * @param Map<UriSummarizerInterface> $summarizers
     */
    public function __construct(
        #[Set(UriSummarizer::class)] private readonyl Map $summarizers;
        private readonyl EmoticonImagifier $emoticonImagifier;
    ) {}
    
    public function prettifyTweet(String tweetMessage): Html
    {
        // split out the URIs and call prettifyUri() for each
    }

    public prettifyUri(URI $uri): string
    {
        // loop through the implementations, looking for one that supports this URI
        for ($this->summarizer as summarizer) {
            $summary = $summarizer->summarize($uri);
            if ($summary != null) {
                return $summary;
            }
       }

        // no summarizer found, just return the URI itself
        return $uri->toString();
    }
}
```

_**Note:** The method `Multibinder::newInstance($module, $type)` can be confusing.
This operation creates a new binder, but doesn't override any existing bindings.
A binder created this way contributes to the existing Set of implementations for
that type. It would create a new set only if one is not already bound._

Finally we must register the plugins themselves. The simplest mechanism to do so
is to list them programatically:

```php
class PrettyTweets
{
    public static function __invoke(): void
    {
        $injector = new Injector(
            new GoogleMapsPluginModule(),
            new BitlyPluginModule(),
            new FlickrPluginModule()
            // ...      
        );

        $injector->getInstance(Frontend::class)->start();
  }
}
(new PrettyTweets)();
```

### MapBinder

マルチバインダーで追加するクラスに名前をつけることができます。

```php
class FlickrPluginModule extends AbstractModule
{
    public function configure(): void 
    {
        $uriBinder = Multibinder::newInstance($this, UriSummarizerInterface::class);
        $uriBinder->add(FlickrPhotoSummarizer::class, 'flickr');

        // ...bind plugin dependencies, such as our Flickr API key
   }
}
```
アプリケーションでは``#[Set(UriSummarizer::class)]`などとアトリビュート指定して注入された`Map`を、束縛で指定しと時の名前で取り出すことができます。

```php

class TweetPrettifier
{
    /**
     * @param Map<UriSummarizerInterface> $summarizers
     */
    public function __construct(
        #[Set(UriSummarizer::class)] private readonyl Map $summarizers;
    ) {}

    public doSomething(): void
    {
        $filickerSummarizer = $this->summarizers['flicker'];
        assert($filickerSummarizer instanceof FlickrPhotoSummarizer);
    }    
}
```

## Map

`Map`オブジェクトは静的解析ではジェネリクスとして扱われます。注入されるインターフェイスがTなら `Map<T>` のように記述します。

```php
/** @param Map<UriSummarizerInterface> $summarizers **/
```

