const ENDPOINT = process.env.AI_HTTP_ENDPOINT || 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttp';
const prompt = process.argv[2] || 'Who is the president of Ghana?';

(async () => {
  console.log('Endpoint:', ENDPOINT);
  console.log('Prompt:', prompt);
  const body = { message: prompt, sessionId: `meta_force_${Date.now()}`, mode: 'general', useWebSearch: true };
  const res = await fetch(ENDPOINT, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (!res.ok) {
    console.error('HTTP', res.status);
    const t = await res.text();
    console.error(t);
    process.exit(1);
  }

  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buf = '';
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    // SSE events separated by double newline
    let idx;
    while ((idx = buf.indexOf('\n\n')) !== -1) {
      const raw = buf.slice(0, idx).trim();
      buf = buf.slice(idx + 2);
      if (!raw) continue;
      const lines = raw.split(/\r?\n/);
      for (const line of lines) {
        if (line.startsWith(':')) continue; // comment
        if (line.startsWith('data:')) {
          const payload = line.slice(5).trim();
          try {
            const obj = JSON.parse(payload);
            console.log('EVENT:', JSON.stringify(obj, null, 2));
          } catch (e) {
            console.log('DATA:', payload);
          }
        } else {
          console.log('RAW LINE:', line);
        }
      }
    }
  }
  if (buf.trim()) console.log('LEFTOVER:', buf.trim());
  console.log('Stream ended');
})();
