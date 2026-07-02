async function sendChat(apiMode, systemPrompt) {
  const log = document.getElementById('log');
  const input = document.getElementById('input');
  const text = input.value.trim();
  if (!text) return;
  input.value = '';

  const add = (role, msg) => {
    const d = document.createElement('div');
    d.className = 'msg ' + role;
    d.textContent = (role === 'user' ? 'You: ' : 'Agent: ') + msg;
    log.appendChild(d);
    log.scrollTop = log.scrollHeight;
  };

  add('user', text);
  try {
    if (apiMode === 'anthropic') {
      const r = await fetch('/omlx/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer mkapikey',
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'qwen3.5:35b-a3b-coding-nvfp4',
          max_tokens: 1024,
          system: systemPrompt,
          messages: [{ role: 'user', content: text }],
        }),
      });
      const j = await r.json();
      const reply =
        (j.content && j.content[0] && j.content[0].text) ||
        j.error?.message ||
        JSON.stringify(j);
      add('assistant', reply);
    } else {
      const r = await fetch('/omlx/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer mkapikey',
        },
        body: JSON.stringify({
          model: 'qwen2.5-coder:14b',
          max_tokens: 1024,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: text },
          ],
        }),
      });
      const j = await r.json();
      add(
        'assistant',
        j.choices?.[0]?.message?.content ||
          j.error?.message ||
          'No response — load a model in oMLX'
      );
    }
  } catch (e) {
    add('assistant', 'Error: ' + e.message);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const sendBtn = document.getElementById('send');
  const input = document.getElementById('input');
  if (!sendBtn || !window.AGENT_CHAT) return;
  const { apiMode, system } = window.AGENT_CHAT;
  sendBtn.addEventListener('click', () => sendChat(apiMode, system));
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendChat(apiMode, system);
    }
  });
});
