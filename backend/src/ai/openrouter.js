const ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';

export const MODEL = 'openai/gpt-oss-120b';

/**
 * Sends a chat completion to OpenRouter and returns the assistant's content.
 *
 * The key is read at call time rather than at import, so tests and the health
 * of the rest of the server do not depend on it being set.
 */
export async function callOpenRouter(messages, { responseFormat } = {}) {
  const apiKey = process.env.OPENROUTER_API_KEY;

  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY is not set');
  }

  const response = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      messages,
      ...(responseFormat ? { response_format: responseFormat } : {}),
    }),
  });

  if (!response.ok) {
    // The body often explains why, but it can echo the request, so only the
    // status is surfaced. Never log the key.
    throw new Error(`OpenRouter request failed (${response.status})`);
  }

  const body = await response.json();
  const content = body.choices?.[0]?.message?.content;

  if (typeof content !== 'string') {
    throw new Error('OpenRouter returned no message content');
  }

  return content;
}
