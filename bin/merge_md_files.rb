require 'fileutils'
require 'yaml'

def extract_order_from_contents(language)
  # Read contents.html to get the proper order
  contents_file = File.expand_path("../_includes/manuals/1.0/#{language}/contents.html", __dir__)
  return nil unless File.exist?(contents_file)
  
  contents = File.read(contents_file)
  
  # Extract permalinks from nav items
  permalinks = contents.scan(/href="\/manuals\/1\.0\/#{language}\/([^"]+\.html)"/).flatten
  
  # Convert HTML filenames to markdown filenames (kebab-case to CamelCase)
  markdown_files = permalinks.map do |permalink|
    # Remove .html extension
    base = permalink.sub('.html', '')
    
    # Skip AI assistant and other non-documentation pages
    skip_pages = ['ai-assistant', 'index', '1page']
    next nil if skip_pages.include?(base)
    
    # Convert kebab-case to CamelCase for markdown files
    # Special cases first
    case base
    when 'getting_started'
      'GettingStarted.md'
    when 'mental_model'
      'MentalModel.md'
    when 'linked_bindings'
      'LinkedBindings.md'
    when 'binding_attributes'
      'BindingAttributes.md'
    when 'instance_bindings'
      'InstanceBindings.md'
    when 'provider_bindings'
      'ProviderBindings.md'
    when 'untargeted_bindings'
      'UntargetedBindings.md'
    when 'constructor_bindings'
      'ConstructorBindings.md'
    when 'builtin_bindings'
      'BuiltinBindings.md'
    when 'contextual_bindings'
      'ContextualBindings.md'
    when 'null_object_binding'
      'NullObjectBinding.md'
    when 'injecting_providers'
      'InjectingProviders.md'
    when 'object_life_cycle'
      'ObjectLifeCycle.md'
    when 'best_practices'
      'BestPractices.md'
    when 'performance_boost'
      'PerformanceBoost.md'
    when 'backward_compatibility'
      'BackwardCompatibility.md'
    else
      # For simple cases, just capitalize first letter
      base.split('_').map(&:capitalize).join + '.md'
    end
  end.compact
  
  markdown_files
end

def strip_frontmatter(content)
  # Remove Jekyll frontmatter from the beginning of the content
  # Handle both normal --- delimiters and any corrupted ones
  content.gsub(/\A.*?---\s*\n.*?\n---\s*\n/m, '').gsub(/\A\d*---\s*\n.*?\n---\s*\n/m, '')
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
          
          combined_file.write("\n### " + stripped_content + "\n")
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