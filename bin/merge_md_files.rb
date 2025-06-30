require 'fileutils'
require 'yaml'

def convert_to_markdown_filename(base_name)
  # Generic kebab-case to CamelCase converter
  # This handles both underscore and hyphen separators
  base_name.split(/[_-]/).map(&:capitalize).join + '.md'
end

def extract_order_from_contents(language)
  # Read contents.html to get the proper order
  contents_file = File.expand_path("../_includes/manuals/1.0/#{language}/contents.html", __dir__)
  unless File.exist?(contents_file)
    puts "Warning: Contents file not found: #{contents_file}"
    return nil
  end
  
  contents = File.read(contents_file)
  
  # Extract permalinks from nav items
  permalinks = contents.scan(/href="\/manuals\/1\.0\/#{language}\/([^"]+\.html)"/).flatten
  
  # Validate that we found some permalinks
  if permalinks.empty?
    puts "Warning: No permalinks found in #{contents_file}. Navigation structure may have changed."
    return nil
  end
  
  puts "Found #{permalinks.length} pages in navigation order"
  
  # Convert HTML filenames to markdown filenames
  markdown_files = permalinks.map do |permalink|
    # Remove .html extension
    base = permalink.sub('.html', '')
    
    # Skip AI assistant and other non-documentation pages
    skip_pages = ['ai-assistant', 'index', '1page']
    next nil if skip_pages.include?(base)
    
    # Convert kebab-case to CamelCase
    convert_to_markdown_filename(base)
  end.compact
  
  markdown_files
end

def strip_frontmatter(content)
  # Remove Jekyll frontmatter only from the very beginning of the file
  # Handle both normal frontmatter and any corrupted patterns
  content.sub(/\A\d*---\s*\n.*?\n---\s*\n/m, '')
end

def generate_combined_file(language, intro_message)
  source_folder = File.expand_path("../manuals/1.0/#{language}/", __dir__)
  output_file = "manuals/1.0/#{language}/1page.md"

  puts "Processing #{language} documentation..."
  raise "Source folder does not exist!" unless File.directory?(source_folder)

  # Get file order from contents.html
  file_order = extract_order_from_contents(language)
  
  if file_order.nil? || file_order.empty?
    puts "Warning: Could not extract order from contents.html, using alphabetical order"
    file_order = Dir.glob(File.join(source_folder, "*.md"))
                    .map { |f| File.basename(f) }
                    .reject { |f| f == "1page.md" || f == "ai-assistant.md" }
                    .sort
  end

  # Generate the combined file
  File.open(output_file, "w") do |combined_file|
    # Write header
    header = <<~EOS
      ---
      layout: docs-#{language}
      title: Ray.Di Complete Manual
      category: Manual
      permalink: /manuals/1.0/#{language}/1page.html
      ---
      
      # Ray.Di Complete Manual
      
    EOS
    
    combined_file.write(header)
    combined_file.write(intro_message + "\n\n")
    combined_file.write("---\n\n")

    # Process each file in order
    file_order.each_with_index do |filename, index|
      filepath = File.join(source_folder, filename)
      
      if File.exist?(filepath)
        begin
          content = File.read(filepath)
          stripped_content = strip_frontmatter(content)
          
          # Skip empty files
          next if stripped_content.strip.empty?
          
          # Add a separator between sections (except for the first one)
          combined_file.write("\n---\n\n") if index > 0
          
          combined_file.write(stripped_content + "\n")
          puts "  Added: #{filename}"
        rescue => e
          puts "  Error processing #{filename}: #{e.message}"
        end
      else
        puts "  Warning: File not found: #{filename}"
      end
    end
    
    # Add best practices section at the end
    bp_folder = File.join(source_folder, "bp")
    if Dir.exist?(bp_folder)
      combined_file.write("\n---\n\n## Best Practices Details\n\n")
      
      bp_files = Dir.glob(File.join(bp_folder, "*.md")).sort
      bp_files.each do |bp_file|
        begin
          content = File.read(bp_file)
          stripped_content = strip_frontmatter(content)
          
          next if stripped_content.strip.empty?
          
          # Remove leading heading if present to avoid duplicate headings
          cleaned_content = stripped_content.lstrip
          if cleaned_content =~ /\A\#{1,6}\s+(.+)/
            cleaned_content = $1.lstrip
          end
          
          combined_file.write("\n### " + cleaned_content + "\n")
          puts "  Added BP: #{File.basename(bp_file)}"
        rescue => e
          puts "  Error processing BP #{bp_file}: #{e.message}"
        end
      end
    end
  end

  puts "Generated: #{output_file}"
  puts "Total sections: #{file_order.length}"
end

# Generate combined files for both languages
generate_combined_file("en", "This comprehensive manual contains all Ray.Di documentation in a single page for easy reference, printing, or offline viewing.")
generate_combined_file("ja", "このページは、Ray.Diの全ドキュメントを1ページにまとめた包括的なマニュアルです。参照、印刷、オフライン閲覧に便利です。")