require 'fileutils'

def generate_combined_file(language, intro_message)
  # マークダウンファイルが存在するフォルダ
  source_folder = File.expand_path("../manuals/1.0/#{language}/", __dir__)
  # 結合されたファイルの出力先
  output_file = "manuals/1.0/#{language}/1page.md"

  puts "Does the source folder exist? #{Dir.exist?(source_folder)}"
  raise "Source folder does not exist!" unless File.directory?(source_folder)

  # ファイルの正しい順序を定義
  file_order = [
    "installation.md",
    "overview.md", 
    "motivation.md",
    "getting-started.md",
    "mental-model.md",
    "scopes.md",
    "bindings.md",
    "linked-bindings.md",
    "binding-attributes.md",
    "instance-bindings.md",
    "provider-bindings.md",
    "untargeted-bindings.md",
    "constructor-bindings.md",
    "builtin-bindings.md",
    "multibindings.md",
    "contextual-bindings.md",
    "null-object-binding.md",
    "injections.md",
    "injecting-providers.md",
    "object-lifecycle.md",
    "aop.md",
    "best-practices.md",
    "grapher.md",
    "integration.md",
    "performance-boost.md",
    "backward-compatibility.md",
    "tutorial1.md",
    "ai-assistant.md"
  ]

  # ファイルを開く
  File.open(output_file, "w") do |combined_file|

    # 全体のヘッダーを書き込む
    combined_file.write("---\nlayout: docs-#{language}\ntitle: 1 Page Manual\ncategory: Manual\npermalink: /manuals/1.0/#{language}/1page.html\n---\n")

    # 追加のメッセージを書き込む
    combined_file.write(intro_message + "\n\n")

    # 順序に従ってファイルを処理
    file_order.each do |filename|
      filepath = File.join(source_folder, filename)
      next unless File.exist?(filepath)
      
      File.open(filepath, "r") do |file|
        # ファイル内容を読む
        content = file.read

        # ヘッダー部分を削除 （"---"で囲まれた部分を削除）
        content.gsub!(/---.*?---/m, '')

        # 出力ファイルに書き込み
        combined_file.write(content + "\n")
      end
    end

    # bp/フォルダ内のファイルも追加
    bp_files = Dir.glob(File.join(source_folder, "bp", "*.md")).sort
    bp_files.each do |filepath|
      File.open(filepath, "r") do |file|
        # ファイル内容を読む
        content = file.read

        # ヘッダー部分を削除 （"---"で囲まれた部分を削除）
        content.gsub!(/---.*?---/m, '')

        # 出力ファイルに書き込み
        combined_file.write(content + "\n")
      end
    end

  end

  puts "Markdown files have been combined into #{output_file}"
end

# 以下の行を使用して関数を2言語で呼び出す
generate_combined_file("ja", "これは全てのマニュアルページを一つにまとめたページです。")
generate_combined_file("en", "This page collects all manual pages in one place.")
