#!/usr/bin/env node
// Small test harness to verify time-sensitive queries return current info
// Usage: node tools/run_time_sensitive_tests.js

const ENDPOINT = process.env.AI_ENDPOINT || 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttpLegacy';

const tests = [
  { id: 'ghana_president', prompt: 'Who is the president of Ghana?' },
  { id: 'epl_leader', prompt: 'Who is currently leading the EPL table?' },
  { id: 'tokyo_population', prompt: 'What is the current population of Tokyo?' },
  { id: 'wassce_curriculum_changes', prompt: 'Have there been any WASSCE curriculum changes in 2025? Please cite sources.' },
  { id: 'nacca_bece_update', prompt: 'Has NaCCA updated the BECE syllabus in 2025? Provide citations if available.' },
  { id: 'waec_exam_changes', prompt: 'Are there any recent WAEC exam format changes in 2025?' },
  // Add additional time-sensitive queries here
];

async function runTest(test) {
  try {
    const body = {
      prompt: test.prompt,
      sessionId: `test_${test.id}_${Date.now()}`,
      mode: 'general',
      useWebSearch: 'auto'
    };

    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    if (!res.ok) {
      const text = await res.text();
      return { ok: false, status: res.status, text };
    }

    const j = await res.json();
    return { ok: true, json: j };
  } catch (e) {
    return { ok: false, error: e.message || String(e) };
  }
}

(async () => {
  console.log(`Using endpoint: ${ENDPOINT}\n`);
  for (const t of tests) {
    console.log('---');
    console.log(`Test: ${t.id}`);
    console.log(`Prompt: ${t.prompt}`);
    const out = await runTest(t);
    if (!out.ok) {
      console.error('ERROR:', out);
      continue;
    }
    const reply = out.json?.reply ?? out.json?.answer ?? JSON.stringify(out.json);
    console.log('Reply:');
    console.log(reply);
    console.log();
  }
})();
