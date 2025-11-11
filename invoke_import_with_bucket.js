// invoke_import_with_bucket.js
// Usage: node invoke_import_with_bucket.js --bucket=<BUCKET> --prefix=<PREFIX> [--url=<FUNCTION_URL>] [--idToken=<FIREBASE_ID_TOKEN>]
const args = require('minimist')(process.argv.slice(2));
const fetch = global.fetch || require('node-fetch');
(async () => {
  try {
    const defaultUrl = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/importGhanaianLanguageQuestions';
    const url = args.url || defaultUrl;
    const bucket = args.bucket;
    const prefix = args.prefix || 'ghanaian_language/';
    const idToken = args.idToken || '';
    if (!bucket) {
      console.error('Missing --bucket');
      process.exit(1);
    }
    const payload = { data: { bucket, prefix } };
    console.log(`Calling ${url} with payload:`, JSON.stringify(payload));
    const headers = { 'Content-Type': 'application/json' };
    if (idToken) headers['Authorization'] = `Bearer ${idToken}`;
    const resp = await fetch(url, { method: 'POST', headers, body: JSON.stringify(payload) });
    const text = await resp.text();
    console.log('Response status:', resp.status);
    try { console.log('Response JSON:', JSON.parse(text)); } catch (e) { console.log('Response body:', text); }
  } catch (e) {
    console.error('Invocation failed:', e);
    process.exit(1);
  }
})();
