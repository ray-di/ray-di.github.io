---
layout: docs-ja
title: ベストプラクティス
category: Manual
permalink: /manuals/1.0/ja/best_practices.html
---
# Ray.Di ベストプラクティス

*   [ミュータビリティの最小化](bp/minimize_mutability.html)
*   [直接依存するものだけを注入する](bp/inject_only_direct_dependencies.html)
*   [インジェクターはできるだけ使用しない（できれば1回だけ）](bp/injecting_the_injector.html)
*   循環する依存関係を避ける
*   [静的な状態を避ける](bp/avoid_static_state.html)
*   [モジュールは高速で副作用がないこと](bp/modules_should_be_fast_and_side_effect_free.html)
*   [モジュール内の条件付きロジックは避ける](bp/avoid_conditional_logic_in_modules.html)
*   [束縛アトリビュートを再利用しない (`#[Qualifiers]`)](bp/dont_reuse_annotations.html)
*   [クラスタイプではなく、機能別にモジュールを整理する](bp/organize_modules_by_feature.html)
*   [モジュールが提供するパブリック束縛の文書化を行う](bp/document_public_bindings.html)
