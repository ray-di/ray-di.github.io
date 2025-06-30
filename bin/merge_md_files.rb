require 'fileutils'
require 'yaml'

def strip_frontmatter(content)
  # More precise regex: anchored to start, handles multiple formats
  content.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
end

def extract_order(path)
  # Extract order from frontmatter or use filename as fallback
  begin
    content = File.read(path)
    frontmatter_match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    return File.basename(path, '.md').downcase unless frontmatter_match
    
    frontmatter = YAML.safe_load(frontmatter_match[1])
    frontmatter['order'] || File.basename(path, '.md').downcase
  rescue => e
    puts "Warning: Could not parse frontmatter for #{path}: #{e.message}"
    File.basename(path, '.md').downcase
  end
end

def generate_combined_file(language, intro_message)
  source_folder = File.expand_path("../manuals/1.0/#{language}/", __dir__)
  output_file = "manuals/1.0/#{language}/1page.md"

  puts "Does the source folder exist? #{Dir.exist?(source_folder)}"
  raise "Source folder does not exist!" unless File.directory?(source_folder)

  # Gather all markdown files (including bp/ subdirectory)
  all_files = Dir.glob(File.join(source_folder, "**", "*.md"))
                 .reject { |f| File.basename(f) == "1page.md" } # Exclude the output file itself
  
  # Sort by frontmatter order or filename
  sorted_files = all_files.sort_by { |f| extract_order(f) }

  # Generate the combined file
  File.open(output_file, "w") do |combined_file|
    # Write header
    header = <<~EOS
      ---
      layout: docs-#{language}
      title: 1 Page Manual
      category: Manual
      permalink: /manuals/1.0/#{language}/1page.html
      ---
    EOS
    
    combined_file.write(header)
    combined_file.write(intro_message + "\n\n")

    # Process each file in order
    sorted_files.each do |filepath|
      begin
        content = File.read(filepath)
        stripped_content = strip_frontmatter(content)
        
        # Skip empty files
        next if stripped_content.strip.empty?
        
        combined_file.write(stripped_content + "\n")
        puts "Included: #{File.basename(filepath)}"
      rescue => e
        puts "Error processing #{filepath}: #{e.message}"
      end
    end
  end

  puts "Markdown files have been combined into #{output_file}"
  puts "Total files processed: #{sorted_files.length}"
end

# Generate combined files for both languages
generate_combined_file("ja", "これは全てのマニュアルページを一つにまとめたページです。")
generate_combined_file("en", "This page collects all manual pages in one place.")