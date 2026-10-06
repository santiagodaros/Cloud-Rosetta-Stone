#!/usr/bin/env node
/**
 * Letra Chica MCP server (stdio, solo lectura).
 *
 * Expone el dataset publicado como herramientas para que un asistente cite
 * gotchas multicloud con su fuente oficial y su fecha de verificación.
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { findCapabilities, findConcepts, findTerraform, formatCapability, formatConcept, formatGotcha, formatPattern, formatTerraform, searchGotchas, t, type Locale } from './core.ts';
import { loadDataset } from './data.ts';

const PROVIDERS = ['azure', 'aws', 'gcp'] as const;
const SEVERITIES = ['security', 'iam', 'networking', 'cost', 'reliability', 'operations'] as const;
const lang = z.enum(['es', 'en']).default('en').describe('Language of the returned text');
const readOnly = { readOnlyHint: true, openWorldHint: false } as const;

const text = (body: string) => ({ content: [{ type: 'text' as const, text: body }] });
const withFooter = (body: string, attribution: string, generatedAt: string) =>
  `${body}\n\n---\nSource: ${attribution}. Dataset generated ${generatedAt}. Quote the official sources above, not this summary.`;

const server = new McpServer({ name: 'letra-chica', version: '0.1.0' });

server.registerTool(
  'search_gotchas',
  {
    title: 'Search multicloud gotchas',
    description:
      'Search documented differences ("gotchas") between Azure, AWS and Google Cloud. Each result has an official source and a verification date. Use it before claiming two cloud services behave the same.',
    inputSchema: {
      query: z.string().describe('Keywords, e.g. "private endpoint dns", "lifecycle prefix", "oidc subject"'),
      provider: z.enum(PROVIDERS).optional(),
      severity: z.enum(SEVERITIES).optional(),
      exam: z.string().optional().describe('Certification code, e.g. AZ-104, SAA-C03, ACE'),
      limit: z.number().int().min(1).max(25).default(8),
      lang,
    },
    annotations: readOnly,
  },
  async ({ query, provider, severity, exam, limit, lang }) => {
    const ds = await loadDataset();
    const hits = searchGotchas(ds, query, { provider, severity, exam }, limit);
    const body = hits.length
      ? hits.map((g) => formatGotcha(g, lang as Locale)).join('\n\n')
      : `No gotchas match "${query}". Try fewer or broader keywords, or lookup_service for the service dictionary.`;
    return text(withFooter(body, ds.attribution, ds.generated_at));
  },
);

server.registerTool(
  'get_gotcha',
  {
    title: 'Get one gotcha',
    description: 'Get a gotcha by its stable key (<pattern>/<cloud>/<id>), as returned by search_gotchas.',
    inputSchema: { key: z.string(), lang },
    annotations: readOnly,
  },
  async ({ key, lang }) => {
    const ds = await loadDataset();
    const g = ds.gotchas.find((x) => x.key === key);
    return text(g ? withFooter(formatGotcha(g, lang as Locale), ds.attribution, ds.generated_at) : `Unknown key "${key}".`);
  },
);

server.registerTool(
  'list_patterns',
  {
    title: 'List architecture patterns',
    description: 'List the architecture patterns compared across the three clouds.',
    inputSchema: { lang },
    annotations: readOnly,
  },
  async ({ lang }) => {
    const ds = await loadDataset();
    return text(ds.patterns.map((p) => `- ${p.id}: ${t(p.title, lang as Locale)}. ${t(p.summary, lang as Locale)}`).join('\n'));
  },
);

server.registerTool(
  'compare_pattern',
  {
    title: 'Compare a pattern across clouds',
    description: 'Show which service implements each role of a pattern on each cloud, plus the gotcha titles per cloud.',
    inputSchema: {
      pattern: z.string().describe('Pattern id from list_patterns'),
      providers: z.array(z.enum(PROVIDERS)).optional().describe('Subset of clouds; default all three'),
      lang,
    },
    annotations: readOnly,
  },
  async ({ pattern, providers, lang }) => {
    const ds = await loadDataset();
    const p = ds.patterns.find((x) => x.id === pattern);
    if (!p) return text(`Unknown pattern "${pattern}". Use list_patterns.`);
    return text(withFooter(formatPattern(p, ds, lang as Locale, providers), ds.attribution, ds.generated_at));
  },
);

server.registerTool(
  'lookup_service',
  {
    title: 'Look up a service across clouds',
    description:
      'Find the equivalent services for a capability (e.g. "private dns", "message queue", "workload identity"), including explicit gaps where a cloud has no direct equivalent.',
    inputSchema: { query: z.string(), lang },
    annotations: readOnly,
  },
  async ({ query, lang }) => {
    const ds = await loadDataset();
    const caps = findCapabilities(ds, query);
    return text(caps.length ? caps.map((c) => formatCapability(c, lang as Locale)).join('\n\n') : `No capability matches "${query}".`);
  },
);

server.registerTool(
  'exam_gotchas',
  {
    title: 'Gotchas for a certification exam',
    description: 'List the gotchas tagged with a certification exam, and the exam status (active, retiring, retired → replacement).',
    inputSchema: { code: z.string().describe('e.g. AZ-700, ANS-C01, PCNE'), lang },
    annotations: readOnly,
  },
  async ({ code, lang }) => {
    const ds = await loadDataset();
    const exam = ds.exams.find((e) => e.code === code.toUpperCase());
    if (!exam) return text(`Unknown exam "${code}". Known: ${ds.exams.map((e) => e.code).join(', ')}.`);
    const head = `${exam.code} · ${exam.name} · status: ${exam.status}${exam.retires_on ? ` (last day ${exam.retires_on})` : ''}${exam.replaced_by ? ` → ${exam.replaced_by}` : ''} · ${exam.url}`;
    const gotchas = ds.gotchas.filter((g) => exam.gotchas.includes(g.key));
    const empty = exam.replaced_by
      ? `No gotchas are tagged with ${exam.code}; see ${exam.replaced_by}.`
      : `No gotchas are tagged with ${exam.code} yet.`;
    const body = gotchas.length ? gotchas.map((g) => formatGotcha(g, lang as Locale)).join('\n\n') : empty;
    return text(withFooter(`${head}\n\n${body}`, ds.attribution, ds.generated_at));
  },
);

server.registerTool(
  'explain_concept',
  {
    title: 'Explain a structural concept across clouds',
    description:
      'How each cloud names and scopes a structural concept: resource hierarchy, billing boundary, network scope, availability zones, tags/labels, resource identifiers, workforce identity. Includes where the analogy breaks, with sources.',
    inputSchema: { query: z.string().describe('e.g. "resource group", "availability zone", "labels", "vpc scope"'), lang },
    annotations: readOnly,
  },
  async ({ query, lang }) => {
    const ds = await loadDataset();
    const hits = findConcepts(ds, query);
    return text(hits.length ? hits.map((c) => formatConcept(c, lang as Locale)).join('\n\n') : `No concept matches "${query}". Known: ${ds.concepts.map((c) => c.id).join(', ')}.`);
  },
);

server.registerTool(
  'terraform_equivalent',
  {
    title: 'Terraform resource equivalents',
    description:
      'Given a Terraform resource type (azurerm_*, aws_*, google_*) or keywords, return the equivalent resources in the other providers, whether the mapping is 1:1, and what changes when it is not. Names are validated against the pinned provider schemas.',
    inputSchema: { query: z.string().describe('e.g. "azurerm_private_endpoint", "aws_s3_bucket_lifecycle_configuration", "peering"'), lang },
    annotations: readOnly,
  },
  async ({ query, lang }) => {
    const ds = await loadDataset();
    const hits = findTerraform(ds, query);
    return text(hits.length ? hits.map((e) => formatTerraform(e, lang as Locale)).join('\n\n') : `No mapping for "${query}" yet.`);
  },
);

await server.connect(new StdioServerTransport());
