import { afterEach, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

import { callOpenRouter, MODEL } from '../src/ai/openrouter.js';

const realFetch = globalThis.fetch;
const realKey = process.env.OPENROUTER_API_KEY;

/** Replaces fetch, recording the call and returning a canned response. */
function stubFetch(response) {
  const calls = [];

  globalThis.fetch = async (url, options) => {
    calls.push({ url, options });
    return response;
  };

  return calls;
}

function jsonResponse(body, { ok = true, status = 200 } = {}) {
  return { ok, status, json: async () => body };
}

const reply = (content) =>
  jsonResponse({ choices: [{ message: { content } }] });

beforeEach(() => {
  process.env.OPENROUTER_API_KEY = 'test-key';
});

afterEach(() => {
  globalThis.fetch = realFetch;
  if (realKey === undefined) {
    delete process.env.OPENROUTER_API_KEY;
  } else {
    process.env.OPENROUTER_API_KEY = realKey;
  }
});

test('the request carries the model, auth header, and messages', async () => {
  const calls = stubFetch(reply('4'));

  const content = await callOpenRouter([{ role: 'user', content: '2+2' }]);

  assert.equal(content, '4');
  assert.equal(calls.length, 1);

  const [{ url, options }] = calls;
  assert.equal(url, 'https://openrouter.ai/api/v1/chat/completions');
  assert.equal(options.method, 'POST');
  assert.equal(options.headers.authorization, 'Bearer test-key');
  assert.match(options.headers['content-type'], /application\/json/);

  const body = JSON.parse(options.body);
  assert.equal(body.model, MODEL);
  assert.equal(body.model, 'openai/gpt-oss-120b');
  assert.deepEqual(body.messages, [{ role: 'user', content: '2+2' }]);
  assert.equal('response_format' in body, false);
});

test('a response format is passed through when given', async () => {
  const calls = stubFetch(reply('{}'));
  const responseFormat = { type: 'json_schema', json_schema: { name: 'x' } };

  await callOpenRouter([{ role: 'user', content: 'hi' }], { responseFormat });

  assert.deepEqual(
    JSON.parse(calls[0].options.body).response_format,
    responseFormat,
  );
});

test('a missing key throws before any network call is made', async () => {
  delete process.env.OPENROUTER_API_KEY;
  const calls = stubFetch(reply('4'));

  await assert.rejects(
    callOpenRouter([{ role: 'user', content: '2+2' }]),
    /OPENROUTER_API_KEY is not set/,
  );
  assert.equal(calls.length, 0);
});

test('a non-200 response surfaces as a clear error', async () => {
  stubFetch(jsonResponse({ error: 'nope' }, { ok: false, status: 429 }));

  await assert.rejects(
    callOpenRouter([{ role: 'user', content: '2+2' }]),
    /OpenRouter request failed \(429\)/,
  );
});

test('the error message never contains the key', async () => {
  process.env.OPENROUTER_API_KEY = 'sk-or-v1-secret-value';
  stubFetch(jsonResponse({}, { ok: false, status: 401 }));

  await assert.rejects(callOpenRouter([{ role: 'user', content: 'x' }]), (error) => {
    assert.equal(error.message.includes('sk-or-v1-secret-value'), false);
    return true;
  });
});

test('a response with no message content is rejected', async () => {
  stubFetch(jsonResponse({ choices: [] }));

  await assert.rejects(
    callOpenRouter([{ role: 'user', content: '2+2' }]),
    /no message content/,
  );
});
