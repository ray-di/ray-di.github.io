Gene<?php
/**
 * Generate llms-full.txt from llms.txt by expanding linked markdown files
 * 
 * This script follows the llms.txt standard and creates a comprehensive
 * documentation file for AI assistants by including the content of all
 * linked markdown files.
 */

declare(strict_types=1);

function generateLlmsFull(): void
{
    $baseDir = dirname(__DIR__);
    $llmsFile = $baseDir . '/llms.txt';
    $outputFile = $baseDir . '/llms-full.txt';
    
    if (!file_exists($llmsFile)) {
        throw new RuntimeException("llms.txt not found at: $llmsFile");
    }
    
    echo "Reading llms.txt...\n";
    $content = file_get_contents($llmsFile);
    
    // Extract the header section (before first ## section with links)
    $lines = explode("\n", $content);
    $headerLines = [];
    $linkSections = [];
    $currentSection = null;
    $inLinkSection = false;
    
    foreach ($lines as $line) {
        // Check if this is a section header
        if (preg_match('/^## (.+)$/', $line, $matches)) {
            $sectionName = $matches[1];
            
            // These sections contain links to expand
            if (in_array($sectionName, ['Docs', 'Bindings', 'Advanced Features', 'Best Practices', 'Performance'])) {
                $inLinkSection = true;
                $currentSection = $sectionName;
                $linkSections[$currentSection] = [];
            } elseif ($sectionName === 'Optional') {
                // Optional section - we'll include the links but mark them as optional
                $inLinkSection = true;
                $currentSection = $sectionName;
                $linkSections[$currentSection] = [];
            } else {
                $inLinkSection = false;
                $headerLines[] = $line;
            }
        } elseif ($inLinkSection && preg_match('/^- \[([^\]]+)\]\(([^)]+)\)/', $line, $matches)) {
            // Extract link information
            $title = $matches[1];
            $url = $matches[2];
            $linkSections[$currentSection][] = [
                'title' => $title,
                'url' => $url,
                'line' => $line
            ];
        } elseif (!$inLinkSection) {
            $headerLines[] = $line;
        }
    }
    
    // Start building the full content
    $fullContent = implode("\n", $headerLines) . "\n";
    
    // Add the link sections for reference
    foreach ($linkSections as $sectionName => $links) {
        $fullContent .= "\n## $sectionName\n\n";
        foreach ($links as $link) {
            $fullContent .= $link['line'] . "\n";
        }
    }
    
    $fullContent .= "\n---\n";
    
    // Process each link and include the content
    foreach ($linkSections as $sectionName => $links) {
        if ($sectionName === 'Optional') {
            continue; // Skip optional content in the expanded version
        }
        
        foreach ($links as $link) {
            $markdownPath = parseMarkdownPath($link['url'], $baseDir);
            if ($markdownPath && file_exists($markdownPath)) {
                echo "Including: {$link['title']} from $markdownPath\n";
                $markdownContent = includeMarkdownFile($markdownPath);
                $fullContent .= "\n" . $markdownContent . "\n";
            } else {
                echo "Warning: Could not find file for {$link['title']} at $markdownPath\n";
            }
        }
    }
    
    // Write the result
    file_put_contents($outputFile, $fullContent);
    echo "Generated llms-full.txt successfully!\n";
    echo "File size: " . number_format(strlen($fullContent)) . " characters\n";
}

function parseMarkdownPath(string $url, string $baseDir): ?string
{
    // Convert URL to local file path
    if (strpos($url, '/manuals/1.0/en/') === 0) {
        $relativePath = ltrim($url, '/');
        return $baseDir . '/' . $relativePath;
    }
    
    return null;
}

function includeMarkdownFile(string $filePath): string
{
    $content = file_get_contents($filePath);
    
    // Remove Jekyll front matter
    $content = preg_replace('/^---\s*\n.*?\n---\s*\n/s', '', $content);
    
    // Clean up the content
    $content = trim($content);
    
    // Convert relative links to absolute ones (basic conversion)
    $content = preg_replace_callback(
        '/\[([^\]]+)\]\(([^)]+)\)/',
        function ($matches) {
            $text = $matches[1];
            $url = $matches[2];
            
            // Skip external links
            if (strpos($url, 'http') === 0) {
                return $matches[0];
            }
            
            // Convert relative markdown links to section references
            if (strpos($url, '.md') !== false) {
                // Simple conversion - could be enhanced
                $sectionName = basename($url, '.md');
                $sectionName = str_replace(['-', '_'], ' ', $sectionName);
                $sectionName = ucwords($sectionName);
                return "[$text](#" . strtolower(str_replace(' ', '-', $sectionName)) . ")";
            }
            
            return $matches[0];
        },
        $content
    );
    
    return $content;
}

// Main execution
try {
    generateLlmsFull();
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}