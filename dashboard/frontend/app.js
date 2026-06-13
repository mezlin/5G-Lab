const API_URL = 'http://localhost:5001/api';

// Poll Metrics
async function fetchMetrics() {
  try {
    const res = await fetch(`${API_URL}/metrics`);
    const data = await res.json();
    
    document.getElementById('active-gnbs').innerText = data.active_gnbs || 0;
    document.getElementById('active-ues').innerText = data.active_ues || 0;

  } catch (err) {
    console.error("Failed to fetch metrics", err);
  }
}

setInterval(fetchMetrics, 5000);
fetchMetrics();

// AI Chat
async function sendMessage() {
  const input = document.getElementById('chat-input-field');
  const text = input.value.trim();
  if (!text) return;

  const chatBox = document.getElementById('chat-box');
  
  // Append user message
  const userMsg = document.createElement('div');
  userMsg.className = 'msg user';
  userMsg.innerHTML = `<div class="msg-avatar">U</div><div class="msg-content">${text}</div>`;
  chatBox.appendChild(userMsg);
  
  input.value = '';
  chatBox.scrollTop = chatBox.scrollHeight;

  // Add thinking placeholder
  const aiThinking = document.createElement('div');
  aiThinking.className = 'msg ai';
  aiThinking.innerHTML = `<div class="msg-avatar">AI</div><div class="msg-content">Thinking...</div>`;
  chatBox.appendChild(aiThinking);
  chatBox.scrollTop = chatBox.scrollHeight;

  try {
    const res = await fetch(`${API_URL}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text })
    });
    const data = await res.json();
    
    chatBox.removeChild(aiThinking);

    if (data.reply || data.action) {
      const aiReply = document.createElement('div');
      aiReply.className = 'msg ai';
      
      let contentHtml = data.reply ? `<p>${data.reply.replace(/\n/g, '<br>')}</p>` : '';
      
      if (data.action) {
        // If the AI proposes an action
        contentHtml += `
          <div class="action-proposal" id="action-${data.actionId}">
            <strong>Action Proposed:</strong>
            <code>${data.action.command}</code>
            <p style="font-size: 0.85rem; margin-top: 5px; color: #666;">${data.action.description}</p>
            <div class="action-buttons">
              <button class="btn-confirm" onclick="confirmAction('${data.actionId}')">Approve & Execute</button>
              <button class="btn-cancel" onclick="cancelAction('${data.actionId}')">Cancel</button>
            </div>
          </div>
        `;
      }

      aiReply.innerHTML = `<div class="msg-avatar">AI</div><div class="msg-content">${contentHtml}</div>`;
      chatBox.appendChild(aiReply);
    } else {
      throw new Error("No reply from AI");
    }
  } catch (err) {
    chatBox.removeChild(aiThinking);
    const errorMsg = document.createElement('div');
    errorMsg.className = 'msg ai';
    errorMsg.innerHTML = `<div class="msg-avatar">AI</div><div class="msg-content" style="color:red;">Error connecting to the AI backend.</div>`;
    chatBox.appendChild(errorMsg);
  }
  
  chatBox.scrollTop = chatBox.scrollHeight;
}

function handleKeyPress(e) {
  if (e.key === 'Enter') {
    sendMessage();
  }
}

async function confirmAction(actionId) {
  const box = document.getElementById(`action-${actionId}`);
  if(box) box.innerHTML = `<strong>Executing...</strong>`;
  try {
    const res = await fetch(`${API_URL}/action/${actionId}/execute`, { method: 'POST' });
    const data = await res.json();
    if(box) box.innerHTML = `<strong style="color: green;">Execution Complete</strong><pre style="font-size: 0.8rem; background: #eee; padding: 5px; margin-top: 5px; border-radius: 4px; overflow-x: auto;">${data.output || 'Success'}</pre>`;
  } catch (e) {
    if(box) box.innerHTML = `<strong style="color: red;">Execution Failed</strong>`;
  }
}

function cancelAction(actionId) {
  const box = document.getElementById(`action-${actionId}`);
  if(box) box.innerHTML = `<strong>Action Cancelled</strong>`;
}
