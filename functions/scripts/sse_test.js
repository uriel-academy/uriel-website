import http from 'http';
import fetch from 'node-fetch';

async function run() {
  const res = await fetch('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatSSE', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: 'Explain Pythagoras theorem in one sentence' })
  });

  if (!res.body) throw new Error('No body');

  res.body.on('data', (chunk) => {
    const s = chunk.toString('utf8');
    process.stdout.write(s);
  });

  res.body.on('end', () => console.log('\n-- done'));
}

run().catch(e => { console.error(e); process.exit(1); });
