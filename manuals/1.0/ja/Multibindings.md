---
layout: docs-ja
title: Multibindings
category: Manual
permalink: /manuals/1.0/ja/multibindings.html
---
# マルチバインディング

_マルチバインダー, マップバインダー の概要_

Multibinderは、プラグインタイプのアーキテクチャを想定しています。

### マルチバインダー

マルチバインディングは、アプリケーションのプラグインを簡単にサポートすることができます。[IDE](https://plugins.jetbrains.com/phpstorm) や [ブラウザ](https://chrome.google.com/webstore/category/extensions) によって普及したこのパターンは、アプリケーションの動作を拡張するためのAPIを公開します。

プラグインの利用者もプラグインの作成者も、Ray.Diを使った拡張可能なアプリケーションのために多くのセットアップコードを書く必要はありません。単にインターフェイスを定義し、実装をバインドし、実装のセットをインジェクトするだけです。どのモジュールも新しい マルチバインダーを作成し、実装のセットの束縛を提供することができます。例として、`http://bit.ly/1mzgW1` のような醜いURIをTwitterで読みやすいように要約するプラグインを使ってみましょう。

まず、プラグインの作者が実装できるインタフェースを定義します。これは通常、いくつかの種類の実装が可能なインターフェイスです。例としてWebサイトごとに異なる、URIを短縮する実装を書いてみます。

```php
interface UriSummarizerInterface
{
    /**
     * 短縮URIを返す。このsummarizerがURIの短縮方法を知らない場合はnullを返す。
     */
    public function summarize(URI $uri): string;
}
```

次に、プラグインの作者にこのインターフェイスを実装してもらいます。以下はFlickrに写真URLを短縮する実装です。

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

プラグイン作者は、マルチバインダを使用して実装を登録します。プラグインによっては、複数の実装を束縛したり、複数の拡張点のインタフェースの実装を束縛することがあります。

```php
class FlickrPluginModule extends AbstractModule
{
    public function configure(): void 
    {
        $uriBinder = Multibinder::newInstance($this, UriSummarizerInterface::class);
        $uriBinder->add(FlickrPhotoSummarizer::class);

        // ...その他、Flickr API キーなど、プラグインの依存性を束縛
   }
}
```

これで、プラグインが公開するサービスを利用できるようになりました。今回はツイートのURIを短縮しています。

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

_**Note:** `Multibinder::newInstance($module, $type)` というメソッドについて

この操作は、新しいバインダを作成しますが、 既存のバインダを上書きすることはありません。この方法で作成されたバインダーで対象の型に対して実装群を加えます。
新しいバインダを作成するのは、バインダがまだ存在しない場合だけです。

最後に、プラグインを登録する必要があります。

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

### マップバインダー

マルチバインダーで追加するクラスに名前をつけることができます。ここでは'flickr'という名前をつけました。

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

アプリケーションでは`#[Set(UriSummarizer::class)]`などとアトリビュート指定して注入された`Map`を、束縛で指定しと時の名前で取り出すことができます。

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

マップバインダーは名前をつけて取り出しやすくしただけで、マルチバインダーとほとんど同じです。

## set()

`set()`メソッドはそれまでの束縛を上書きします。

```php
$uriBinder = Multibinder::newInstance($this, UriSummarizerInterface::class);
$uriBinder->set(FlickrPhotoSummarizer::class, 'flickr');
```

## Map

`Map`オブジェクトは静的解析ではジェネリクスとして扱われます。注入されるインターフェイスがTなら `Map<T>` のように記述します。

```php
/** @param Map<UriSummarizerInterface> $summarizers **/
```
