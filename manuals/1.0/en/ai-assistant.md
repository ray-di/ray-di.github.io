---
layout: docs-en
title: Ray.Di AI Assistant
category: Manual
permalink: /manuals/1.0/en/ai-assistant.html
---

# Ray.Di AI Assistant

Explore resources that use the power of AI to support Ray.Di development.

## OpenAI GPTs - Ray.Di Assistant

[Ray.Di Assistant](https://chatgpt.com/g/g-SPAwqfqd4-ray-di-assistant) is a custom GPT trained to answer questions specifically about the Ray.Di framework.

<div class="info-box">
  <p><strong>Note:</strong> An OpenAI Plus account is required to use GPTs.</p>
</div>

## AI support with llms-full.txt

To give another AI assistant (such as Claude or Gemini) knowledge of Ray.Di, copy the contents of llms-full.txt with the button below, or download it from [/llms-full.txt](/llms-full.txt), and paste it at the start of your conversation with the AI.

### What is llms.txt?

The `llms-full.txt` file follows the `llms.txt` standard. It is a simple way to share important information with AI models in concise Markdown. This lets an AI assistant quickly understand key details, such as the Ray.Di framework, without extraneous information. See [llmstxt.org](https://llmstxt.org/) for details.

<button id="copyLlmsText" class="copy-button">Copy llms-full.txt</button>
<span id="copyStatus" class="copy-status"></span>

<div class="usage-guide">
  <h3>How to use the copied information</h3>
  <ul>
    <li><strong>Claude:</strong> Paste it at the start of the conversation, or upload it as a project</li>
    <li><strong>Other AI assistants:</strong> Paste it at the start of the conversation and add a note: "This is information about Ray.Di. Please understand it before answering my questions."</li>
  </ul>
  <p>If the AI assistant has no prior knowledge of Ray.Di, be sure to provide this information.</p>
</div>

---

<script>
document.getElementById('copyLlmsText').addEventListener('click', function() {
  // Fetch the llms-full.txt file from the root
  fetch('/llms-full.txt')
    .then(response => {
      if (!response.ok) {
        throw new Error('File not found');
      }
      return response.text();
    })
    .then(text => {
      navigator.clipboard.writeText(text).then(function() {
        const status = document.getElementById('copyStatus');
        status.textContent = 'Copied!';
        setTimeout(function() {
          status.textContent = '';
        }, 2000);
      }).catch(function(err) {
        console.error('Failed to copy to the clipboard', err);
        alert('Failed to copy to the clipboard.');
      });
    })
    .catch(error => {
      console.error('Failed to load the file:', error);
      alert('Failed to load llms-full.txt.');
    });
});
</script>

<style>
.info-box {
  background-color: #f8f9fa;
  border-left: 4px solid #17a2b8;
  padding: 15px;
  margin: 20px 0;
  border-radius: 4px;
}

.usage-guide {
  background-color: #fff3cd;
  border-left: 4px solid #ffc107;
  padding: 15px;
  margin: 20px 0;
  border-radius: 4px;
}

.usage-guide h3 {
  margin-top: 0;
  color: #856404;
}

.copy-button {
  background-color: #4CAF50;
  border: none;
  color: white;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  font-size: 16px;
  margin: 4px 2px;
  cursor: pointer;
  border-radius: 4px;
  transition: background-color 0.3s;
}

.copy-button:hover {
  background-color: #45a049;
}

.copy-status {
  margin-left: 10px;
  color: #4CAF50;
  font-weight: bold;
}
</style>
