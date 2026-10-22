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
  <p><strong>Note:</strong> You need a ChatGPT account and must be signed in to use GPTs.</p>
</div>

## AI support with llms-full.txt

To give another AI assistant (such as Claude or Gemini) knowledge of Ray.Di, copy the contents of llms-full.txt with the button below, or download it from [/llms-full.txt](/llms-full.txt), and paste it at the start of your conversation with the AI.

### What is llms.txt?

The `llms-full.txt` file follows the `llms.txt` standard. It is a simple way to share important information with AI models in concise Markdown. This lets an AI assistant quickly understand key details, such as the Ray.Di framework, without extraneous information. See [llmstxt.org](https://llmstxt.org/) for details.

<button id="copyLlmsText" class="copy-button">Copy llms-full.txt</button>
<span id="copyStatus" class="copy-status" role="status" aria-live="polite"></span>

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
(function () {
  const button = document.getElementById('copyLlmsText');
  const status = document.getElementById('copyStatus');
  let llmsText = null;

  // Load the file once so the click handler can write to the clipboard without awaiting a fetch
  fetch('/llms-full.txt')
    .then(response => {
      if (!response.ok) {
        throw new Error('File not found');
      }
      return response.text();
    })
    .then(text => {
      llmsText = text;
    })
    .catch(error => {
      console.error('Failed to load the file:', error);
      status.textContent = 'Failed to load llms-full.txt.';
    });

  function showStatus(message) {
    status.textContent = message;
    setTimeout(function() {
      status.textContent = '';
    }, 2000);
  }

  // Fallback for browsers that reject the async Clipboard API
  function copyWithTextarea(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.top = '-1000px';
    document.body.appendChild(textarea);
    textarea.select();
    let copied = false;
    try {
      copied = document.execCommand('copy');
    } catch (e) {
      copied = false;
    }
    document.body.removeChild(textarea);
    return copied;
  }

  function succeeded() {
    showStatus('Copied!');
  }

  function failed(error) {
    console.error('Failed to copy to the clipboard', error);
    alert('Failed to copy to the clipboard.');
  }

  button.addEventListener('click', function() {
    if (llmsText === null) {
      showStatus('Not loaded yet. Please try again in a moment.');
      return;
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      // Called synchronously from the click, so transient user activation is still valid
      navigator.clipboard.writeText(llmsText).then(succeeded, function(error) {
        if (copyWithTextarea(llmsText)) {
          succeeded();
        } else {
          failed(error);
        }
      });
      return;
    }
    if (copyWithTextarea(llmsText)) {
      succeeded();
    } else {
      failed(new Error('Clipboard API not available'));
    }
  });
})();
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
