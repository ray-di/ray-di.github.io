---
layout: docs-en
title: Multibindings
category: Manual
permalink: /manuals/1.0/en/multibindings.html
---
# Multibindings

_Overview of Multibinder, MapBinder_

Multibinder is intended for plugin-type architectures.

## Multibinding

Using `Multibinder` to host plugins.

### Multibinder

Multibindings make it easy to support plugins in your application. Made popular
by [IDEs](https://plugins.jetbrains.com/phpstorm) and [browsers](https://chrome.google.com/webstore/category/extensions), this pattern exposes APIs
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
    public function summarize(Uri $uri): string;
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

    public function summarize(Uri $uri): ?string
    {
        $match = $this->matcher->match($uri);
        if (! $match) {
            return null;
        }
        $id = $this->matcher->group(1);
        $photo = Photo::lookup($id);

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
        $uriBinder->addBinding()->to(FlickrPhotoSummarizer::class);

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
        #[Set(UriSummarizerInterface::class)] private readonly Map $summarizers;
        private readonly EmoticonImagifier $emoticonImagifier;
    ) {}
    
    public function prettifyTweet(String tweetMessage): Html
    {
        // split out the URIs and call prettifyUri() for each
    }

    public function prettifyUri(Uri $uri): string
    {
        // loop through the implementations, looking for one that supports this URI
        foreach ($this->summarizer as summarizer) {
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
    public function __invoke(): void
    {
        $injector = new Injector(
            new class extends AbstractModule {
                protected function configure(): void
                {
                    $this->install(new TweetModule());
                    $this->install(new FlickrPluginModule());
                    $this->install(new GoogleMapsPluginModule());
                    $this->install(new BitlyPluginModule());
                    // ... any other plugins
                }
            }
        );

        $injector->getInstance(Frontend::class)->start();
  }
}
(new PrettyTweets)();
```

### MapBinder

You can name the classes you add in the multibinder.

```php
class FlickrPluginModule extends AbstractModule
{
    public function configure(): void 
    {
        $uriBinder = Multibinder::newInstance($this, UriSummarizerInterface::class);
        $uriBinder->addBinding('flickr')->to(FlickrPhotoSummarizer::class);

        // ...bind plugin dependencies, such as our Flickr API key
   }
}
```
In the application, you can retrieve a `Map` injected by specifying attributes such as ``#[Set(UriSummarizer::class)]`` with the name as it was when specified by the binding.

```php

class TweetPrettifier
{
    /**
     * @param Map<UriSummarizerInterface> $summarizers
     */
    public function __construct(
        #[Set(UriSummarizer::class)] private readonly Map $summarizers;
    ) {}

    public doSomething(): void
    {
        $flickrSummarizer = $this->summarizers['flickr'];
        assert($flickrSummarizer instanceof FlickrPhotoSummarizer);
    }    
}
```

## Set binding

The `setBinding()` method overrides any previous binding.

```php
$UriBinder = Multibinder::newInstance($this, UriSummarizerInterface::class);
$UriBinder->setBinding('flickr')->to(FlickrPhotoSummarizer::class);
```

## Map

`Map` objects are treated as generics in static analysis. If the injected interface is T, it is written as `Map<T>`.

```php
/** @param Map<UriSummarizerInterface> $summarizers **/
```

## Annotation

Since it is not possible to annotate the argument, annotate the property to be assigned with the same name and annotate the property with `@Set`.

```php
class TweetPrettifier
{
    /** @Set(UriSummarizer::class) */
    private $summarizers;
    
    /**
     * @param Map<UriSummarizerInterface> $summarizers
     */
    public function __construct(Map $summarizers) {
        $this->summarizers = $summarizers;
    }
}
```
