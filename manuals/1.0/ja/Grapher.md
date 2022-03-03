---
layout: docs-ja
title: Grapher
category: Manual
permalink: /manuals/1.0/ja/grapher.html
---
## Ray.Diアプリケーションのグラフ化

高度なアプリケーションを作成した場合、Ray.DiのリッチなイントロスペクションAPIにより、オブジェクトグラフを詳細に記述することができます。オブジェクトビジュアルグラファーは、このデータを理解しやすいビジュアライゼーションとして公開します。複雑なアプリケーションの複数のクラスのバインディングや依存関係を、統一されたダイアグラムで表示することができます。

### .dotファイルの生成
Ray.Diのgrapherは、オープンソースのグラフ可視化パッケージである[GraphViz](http://www.graphviz.org/)を大きく活用しています。グラフの仕様と視覚化・レイアウトをきれいに分離することができます。Injector用のグラフ.dotファイルを作成するには、以下のコードを使用します。

```php
use Ray\ObjectGrapher\ObjectGrapher;

$dot = (new ObjectGrapher)(new FooModule);
file_put_contents('path/to/graph.dot', $dot);
```

### .dotファイル
上記のコードを実行すると、グラフを指定した.dotファイルが生成されます。ファイルの各エントリは、グラフのノードまたはエッジを表します。以下は.dotファイルのサンプルです。

```dot
digraph injector {
graph [rankdir=TB];
dependency_BEAR_Resource_ResourceInterface_ [style=dashed, margin=0.02, label=<<table cellspacing="0" cellpadding="5" cellborder="0" border="0"><tr><td align="left" port="header" bgcolor="#ffffff"><font color="#000000">BEAR\\Resource\\ResourceInterface<br align="left"/></font></td></tr></table>>, shape=box]
dependency_BEAR_Resource_FactoryInterface_ [style=dashed, margin=0.02, label=<<table cellspacing="0" cellpadding="5" cellborder="0" border="0"><tr><td align="left" port="header" bgcolor="#ffffff"><font color="#000000">BEAR\\Resource\\FactoryInterface<br align="left"/></font></td></tr></table>>, shape=box]
dependency_BEAR_Resource_ResourceInterface_ -> class_BEAR_Resource_Resource [style=dashed, arrowtail=none, arrowhead=onormal]
dependency_BEAR_Resource_FactoryInterface_ -> class_BEAR_Resource_Factory [style=dashed, arrowtail=none, arrowhead=onormal]
```

### .dotファイルのレンダリング
そのコードを[GraphvizOnline](https://dreampuf.github.io/GraphvizOnline/)に貼り付けて、レンダリングすることができます。

Linuxでは、コマンドラインのdotツールを使って、.dotファイルを画像に変換することができます。

```shell
dot -T png graph.dot > graph.png
```

![graph](https://user-images.githubusercontent.com/529021/72650686-866ec100-39c4-11ea-8b49-2d86d991dc6d.png)


#### グラフ表示

エッジ
   * **実線エッジ** は、実装から依存する型への依存を表します。
   * **破線のエッジ** は、タイプからその実装へのバインディングを表します。
   * **二重矢印** は、バインディングまたは依存関係が `Provider` にあることを表します。

ノード
   * 実装タイプは *黒背景で表示されます*。
   * 実装のインスタンスには *灰色の背景があります*。
