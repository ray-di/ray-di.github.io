---
layout: docs-ja
title: 束縛の診断
category: Manual
permalink: /manuals/1.0/ja/binding_diagnostics.html
---
# 束縛の診断

_bindings.md とプロベナンスログの概要_

書き込み可能なディレクトリを明示して `Injector` を作成すると、Ray.Di はコンテナがどのように構成されたかを記録し、そのディレクトリに `bindings.md` を書き出します。

```php
$injector = new Injector(new AppModule(), $tmpDir); // $tmpDir/bindings.md を出力
```

ファイルには解決済みの束縛、それを構成したモジュール、そして構成過程のプロベナンス（由来）ログが含まれます。

- `bind` — 束縛が登録された
- `replace` — 後の束縛が先の束縛を置き換えた（`override()` など）
- `keep` — 同じキーの後の束縛が破棄された
- `move` — 束縛がリネームされた

衝突で負けたエントリは破棄（discarded）として表示されるので、どの束縛が実際に有効になったかを確認できます。

書き込みはベストエフォートかつアトミックです。診断がインジェクションを妨げることはなく、束縛に変化がなければ再書き込みも行われません。

## HTMLビューア

[ray/bindings](https://github.com/ray-di/Ray.Bindings) パッケージは `bindings.md` をオブジェクトグラフ付きのインタラクティブなHTMLページとして描画します。

```bash
composer require --dev ray/bindings
vendor/bin/bindings-html var/tmp/bindings.md composer.lock > bindings.html
```

<img src="/images/bindings.png" alt="bindings.html: オブジェクトグラフ、サマリー、束縛一覧" width="100%">

BEAR.Sunday アプリケーションでは [BEAR.ApiDoc](https://github.com/bearsunday/BEAR.ApiDoc) の `bindings` フォーマットで同じページを生成できます。

注: 2.22.1–2.22.2 に含まれていた `Ray\Bindings\*` クラスと `bin/bindings-html` は 2.23.0 でコアから外れました。上記パッケージがその後継です。
