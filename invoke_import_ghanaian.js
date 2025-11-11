// invoke_import_ghanaian.js
// Usage: node invoke_import_ghanaian.js --url=<FUNCTION_URL> --assetsDir=<relative/path> [--idToken=<FIREBASE_ID_TOKEN>]
// If no --url provided, defaults to the typical callable URL for your project.

const args = require('minimist')(process.argv.slice(2));
const fetch = global.fetch || require('node-fetch');

(async () => {
  try {
    const defaultUrl = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/importGhanaianLanguageQuestions';
    const url = args.url || defaultUrl;
    const assetsDir = args.assetsDir || '';
    const idToken = args.idToken || '';

    const payload = { data: {} };
    if (assetsDir) payload.data.assetsDir = assetsDir;

    console.log(`Calling ${url} with payload:`, JSON.stringify(payload));

    const headers = { 'Content-Type': 'application/json' };
    if (idToken) headers['Authorization'] = `Bearer ${idToken}`;

    const resp = await fetch(url, { method: 'POST', headers, body: JSON.stringify(payload) });
    const text = await resp.text();
    console.log('Response status:', resp.status);
    try {
      console.log('Response JSON:', JSON.parse(text));
    } catch (e) {
      console.log('Response body:', text);
    }
  } catch (e) {
    console.error('Invocation failed:', e);
    process.exit(1);
  }
})();
