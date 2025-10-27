#!/usr/bin/env node
// Streaming test harness for aiChatStream and aiChatSSE endpoints
// It will open a streaming connection, print incremental data, and time out after a short period.

const AI_STREAM_ENDPOINT = process.env.AI_STREAM_ENDPOINT || 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatStream';
const AI_SSE_ENDPOINT = process.env.AI_SSE_ENDPOINT || 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatSSE';

const tests = [
  { id: 'ghana_president', prompt: 'Who is the president of Ghana?' },
  { id: 'epl_leader', prompt: 'Who is currently leading the EPL table?' },
  { id: 'wassce_curriculum_changes', prompt: 'Have there been any WASSCE curriculum changes in 2025? Please cite sources.' },
];

const { TextDecoder } = global;

async function runStreamFetch(endpoint, prompt) {
  const body = { prompt, sessionId: `stream_test_${Date.now()}`, mode: 'general', useWebSearch: 'auto' };
  const res = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let done = false;
  let accumulated = '';
  while (!done) {
    const { value, done: rdone } = await reader.read();
    if (value) {
      const chunk = dec.decode(value, { stream: true });
      process.stdout.write(chunk);
      accumulated += chunk;
    }
    done = rdone;
  }
  console.log('\n[stream completed]\n');
  return accumulated;
}

async function runSseFetch(endpoint, prompt) {
  const body = { prompt, sessionId: `sse_test_${Date.now()}`, mode: 'general', useWebSearch: 'auto' };
  const res = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buffer = '';
  let done = false;
  while (!done) {
    const { value, done: rdone } = await reader.read();
    if (value) {
      buffer += dec.decode(value, { stream: true });
      // SSE events are delimited by double newlines
      let idx;
      while ((idx = buffer.indexOf('\n\n')) !== -1) {
        const raw = buffer.slice(0, idx).trim();
        buffer = buffer.slice(idx + 2);
        if (raw.length === 0) continue;
        // parse simple lines
        const lines = raw.split(/\r?\n/);
        for (const line of lines) {
          if (line.startsWith('data:')) {
            const payload = line.slice(5).trim();
            try { console.log('[SSE data]', JSON.parse(payload)); } catch (_) { console.log('[SSE data]', payload); }
          } else if (line.startsWith('event:')) {
            console.log('[SSE event]', line.slice(6).trim());
          } else {
            console.log('[SSE raw]', line);
          }
        }
      }
    }
    done = rdone;
  }
  if (buffer.trim().length) console.log('[SSE leftover]', buffer.trim());
  console.log('\n[sse completed]\n');
}

(async () => {
  console.log('Stream endpoint:', AI_STREAM_ENDPOINT);
  console.log('SSE endpoint:', AI_SSE_ENDPOINT);
  for (const t of tests) {
    console.log('---');
    console.log('Test:', t.id);
    console.log('Prompt:', t.prompt);
    try {
      console.log('\n[aiChatStream output]');
      await runStreamFetch(AI_STREAM_ENDPOINT, t.prompt);
    } catch (e) {
      console.error('[aiChatStream error]', e.message || e);
    }
    try {
      console.log('\n[aiChatSSE output]');
      await runSseFetch(AI_SSE_ENDPOINT, t.prompt);
    } catch (e) {
      console.error('[aiChatSSE error]', e.message || e);
    }
  }
})();
