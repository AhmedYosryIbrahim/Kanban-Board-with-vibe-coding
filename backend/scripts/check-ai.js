// Live OpenRouter connectivity check. Makes a real request and spends tokens,
// so it is deliberately not part of `npm test` - the automated suite must run
// without network access.
//
//   npm run check:ai
//
import { callOpenRouter, MODEL } from '../src/ai/openrouter.js';

const answer = await callOpenRouter([
  { role: 'user', content: 'What is 2+2? Reply with just the number.' },
]);

console.log(`model:  ${MODEL}`);
console.log(`answer: ${answer.trim()}`);

if (!answer.includes('4')) {
  console.error('Connectivity check failed: expected the answer to contain 4');
  process.exit(1);
}

console.log('Connectivity check passed');
