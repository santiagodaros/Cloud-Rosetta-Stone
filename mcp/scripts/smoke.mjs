// Prueba de humo end-to-end: levanta el server por stdio contra un dataset
// (por defecto el build local del sitio) y llama a cada herramienta.
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';

const data = process.env.LETRA_CHICA_DATA ?? fileURLToPath(new URL('../../dist/api/v1', import.meta.url));
const server = fileURLToPath(new URL('../dist/index.js', import.meta.url));
const client = new Client({ name: 'smoke', version: '0' });
await client.connect(new StdioClientTransport({ command: process.execPath, args: [server], env: { ...process.env, LETRA_CHICA_DATA: data } }));

const expectText = async (name, args, pattern) => {
  const res = await client.callTool({ name, arguments: args });
  const text = res.content?.[0]?.text ?? '';
  if (res.isError || !pattern.test(text)) throw new Error(`${name} → unexpected output:\n${text.slice(0, 500)}`);
  console.log(`ok ${name}`);
};

const tools = (await client.listTools()).tools.map((t) => t.name).sort();
const expected = ['compare_pattern', 'exam_gotchas', 'get_gotcha', 'list_patterns', 'lookup_service', 'search_gotchas'];
if (JSON.stringify(tools) !== JSON.stringify(expected)) throw new Error(`tools: ${tools}`);

await expectText('search_gotchas', { query: 'private endpoint dns' }, /Sources: https:\/\//);
await expectText('get_gotcha', { key: 'object-storage-ttl/azure/prefix-includes-container' }, /verified_at/);
await expectText('list_patterns', {}, /hybrid-private-dns/);
await expectText('compare_pattern', { pattern: 'ci-oidc-federation' }, /\| Role \| azure \| aws \| gcp \|/);
await expectText('lookup_service', { query: 'message queue' }, /azure:/);
await expectText('exam_gotchas', { code: 'AZ-500' }, /retired.*SC-500/);
await client.close();
