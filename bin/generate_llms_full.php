<?php
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
            $linkableSections = [
                'Getting Started',
                'Core Features', 
                'Binding Types',
                'Advanced Features',
                'Best Practices',
                'Performance & Tools',
                'Additional Resources'
            ];
            
            if (in_array($sectionName, $linkableSections)) {
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

    // Add the link sections for reference with internal anchors
    foreach ($linkSections as $sectionName => $links) {
        $fullContent .= "\n## $sectionName\n\n";
        foreach ($links as $link) {
            // Convert file path links to internal anchors
            $anchorName = basename($link['url'], '.md');
            $anchorName = strtolower(str_replace(['_', ' '], '-', $anchorName));
            $internalLink = "- [{$link['title']}](#{$anchorName}): " . substr($link['line'], strpos($link['line'], ':') + 1);
            $fullContent .= $internalLink . "\n";
        }
    }

    $fullContent .= "\n---\n";

    // Process each link and include the content
    foreach ($linkSections as $sectionName => $links) {
        foreach ($links as $link) {
            $markdownPath = parseMarkdownPath($link['url'], $baseDir);
            if ($markdownPath && file_exists($markdownPath) && is_readable($markdownPath)) {
                echo "Including: {$link['title']} from $markdownPath\n";
                $markdownContent = includeMarkdownFile($markdownPath);
                if ($markdownContent === false || $markdownContent === null || trim($markdownContent) === '') {
                    echo "Error: Failed to read or invalid markdown content in {$link['title']} ($markdownPath)\n";
                    continue;
                }
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

    // Remove Jekyll front matter (handles optional whitespace/comments before, and flexible closing '---')
    $content = preg_replace('/\A(?:\s*|<!--.*?-->\s*)*---\s*\n(.*?)\n---\s*(?:\n|$)/s', '', $content);

    // Clean up the content
    $content = trim($content);

    // Convert relative links to section references, handling anchors and query parameters
    $content = preg_replace_callback(
        '/\[([^\]]+)\]\(([^)]+)\)/',
        function ($matches) {
            $text = $matches[1];
            $url = $matches[2];

            // Skip external links
            if (preg_match('#^(?:[a-z][a-z0-9+\-.]*:)?//#i', $url)) {
                return $matches[0];
            }

            // Only process .md links (with or without anchors/query)
            if (preg_match('/\.md(\?|#|$)/i', $url)) {
                // Split off anchor and query if present
                $urlParts = parse_url($url);
                $file = $urlParts['path'] ?? $url;
                $anchor = $urlParts['fragment'] ?? '';
                // Ignore query parameters for anchor generation, but preserve them in the output if present
                $query = isset($urlParts['query']) ? '?' . $urlParts['query'] : '';

                // Generate section name from file name
                $sectionName = basename($file, '.md');
                $sectionName = str_replace(['-', '_'], ' ', $sectionName);
                $sectionName = ucwords($sectionName);
                $sectionAnchor = strtolower(str_replace(' ', '-', $sectionName));

                // If original link had an anchor, append it
                if ($anchor !== '') {
                    $sectionAnchor .= '-' . strtolower(str_replace([' ', '_'], '-', $anchor));
                }

                return "[$text](#" . $sectionAnchor . ")";
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
