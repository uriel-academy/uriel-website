import fetch from 'node-fetch';

async function run() {
  const res = await fetch('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatStream', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: 'Explain Pythagoras theorem in one sentence' })
  });

  if (!res.body) {
    console.error('No body');
    process.exit(1);
  }

  res.body.on('data', (chunk) => {
    try { process.stdout.write(chunk.toString('utf8')); } catch (e) { process.stdout.write(String(chunk)); }
  });

  res.body.on('end', () => {
    console.log('\n-- done');
  });

  res.body.on('error', (err) => {
    console.error('Stream error', err);
    process.exit(1);
  });
}

run().catch(e => { console.error(e); process.exit(1); });
