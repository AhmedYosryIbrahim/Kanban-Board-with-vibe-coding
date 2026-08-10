import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';

import { createApp } from '../src/app.js';

const staticDir = fileURLToPath(new URL('./fixtures/web', import.meta.url));

let server;
let baseUrl;

before(async () => {
  server = createApp({ staticDir }).listen(0);
  await once(server, 'listening');
  baseUrl = `http://localhost:${server.address().port}`;
});

after(() => {
  server.close();
});

test('GET /api/health returns ok', async () => {
  const response = await fetch(`${baseUrl}/api/health`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('GET / serves the web app entry point', async () => {
  const response = await fetch(`${baseUrl}/`);

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /text\/html/);
  assert.match(await response.text(), /flutter_bootstrap\.js/);
});

test('static assets are served from the build directory', async () => {
  const response = await fetch(`${baseUrl}/flutter_bootstrap.js`);

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /javascript/);
  assert.match(await response.text(), /bootstrap/);
});

test('an unknown path falls back to the web app entry point', async () => {
  const response = await fetch(`${baseUrl}/some/client/route`);

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /text\/html/);
  assert.match(await response.text(), /flutter_bootstrap\.js/);
});

test('an unknown API route returns JSON 404, not the SPA fallback', async () => {
  const response = await fetch(`${baseUrl}/api/nope`);

  assert.equal(response.status, 404);
  assert.match(response.headers.get('content-type'), /application\/json/);
  assert.deepEqual(await response.json(), { error: 'Not found' });
});

test('an unknown API route returns JSON 404 for non-GET methods too', async () => {
  const response = await fetch(`${baseUrl}/api/nope`, { method: 'POST' });

  assert.equal(response.status, 404);
  assert.match(response.headers.get('content-type'), /application\/json/);
});
