/**
 * `pnpm new:pattern <slug> [capability...]` — genera el esqueleto de un patrón nuevo.
 *
 * Crea `pattern.yaml` en estado draft, plantillas `<nube>.yaml.draft` (el loader las
 * ignora hasta que las renombres a `<nube>.yaml`) y un módulo de Terraform por nube con
 * los providers pinneados igual que el resto del repo y un test mínimo con mock_provider.
 */
import { existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { loadContent } from '../src/lib/content.ts';
import { PROVIDERS, type Provider } from '../src/lib/schema.ts';

const TF_PROVIDER: Record<Provider, string> = { azure: 'azurerm', aws: 'aws', gcp: 'google' };

const [slug, ...capabilities] = process.argv.slice(2);
if (!slug || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) {
  console.error('Uso: pnpm new:pattern <slug-kebab-case> [capability-id ...]');
  process.exit(1);
}

const root = process.cwd();
const dir = join(root, 'content', 'patterns', slug);
if (existsSync(dir)) {
  console.error(`Ya existe ${dir}`);
  process.exit(1);
}

const { capabilities: known, patterns } = loadContent(root);
const knownIds = new Set(known.map((c) => c.id));
const unknown = capabilities.filter((c) => !knownIds.has(c));
if (unknown.length) {
  console.error(`Capabilities inexistentes: ${unknown.join(', ')}\nDisponibles: ${[...knownIds].sort().join(', ')}`);
  process.exit(1);
}

/** Reusa versions.tf de un patrón existente para que las versiones queden alineadas (Renovate las sube juntas). */
function versionsTf(provider: Provider): string {
  const existing = patterns.map((p) => p.terraform[provider]).find(Boolean);
  const file = existing?.files.find((f) => f.name === 'versions.tf');
  if (file) return file.code;
  return `terraform {\n  required_version = ">= 1.7.0"\n\n  required_providers {\n    ${TF_PROVIDER[provider]} = {\n      source  = "hashicorp/${TF_PROVIDER[provider]}"\n      version = "TODO"\n    }\n  }\n}\n`;
}

const roles = [
  '  - id: client\n    kind: actor\n    label: { es: Cliente, en: Client }',
  ...capabilities.map((c) => `  - id: ${c}\n    kind: capability\n    capability: ${c}\n    label: { es: TODO, en: TODO }`),
];
const edges = capabilities.length
  ? capabilities.map((c) => `  - { from: client, to: ${c} }`)
  : ['  # - { from: client, to: <rol> }'];

mkdirSync(dir, { recursive: true });
writeFileSync(
  join(dir, 'pattern.yaml'),
  `id: ${slug}
status: draft
category: compute-web # compute-web | async-event | storage-data | networking | identity
title:
  es: TODO
  en: TODO
summary:
  es: TODO — una oración, qué logra el patrón.
problem:
  es: TODO — el problema de negocio y sus requisitos, sin nombrar servicios.
roles:
${roles.join('\n')}
edges:
${edges.join('\n')}
tags: []
`,
);

for (const provider of PROVIDERS) {
  const bindings = capabilities.map((c) => `  ${c}:\n    service: TODO\n    # config: SKU/tier/flag que hace funcionar el patrón`).join('\n');
  writeFileSync(
    join(dir, `${provider}.yaml.draft`),
    `# Renombrá a ${provider}.yaml cuando tenga al menos un gotcha con fuente oficial.
provider: ${provider}
bindings:
${bindings || '  {}'}
gotchas:
  - id: TODO
    severity: cost # security | iam | networking | cost | reliability | operations
    title:
      es: TODO
    body:
      es: TODO — hecho verificable + consecuencia + qué hacer.
    sources:
      - https://TODO-documentacion-oficial
    verified_at: ${new Date().toISOString().slice(0, 10)}
    exams: []
cost:
  scales_to_zero: 'partial' # yes | no | partial
  fixed_cost_drivers: []
  notes:
    es: TODO
`,
  );

  const tfDir = join(dir, 'terraform', provider);
  mkdirSync(join(tfDir, 'tests'), { recursive: true });
  writeFileSync(join(tfDir, 'versions.tf'), versionsTf(provider));
  writeFileSync(
    join(tfDir, 'variables.tf'),
    `variable "name" {\n  description = "Prefijo para nombrar los recursos."\n  type        = string\n}\n`,
  );
  writeFileSync(join(tfDir, 'main.tf'), `# ${slug} — ${provider}\n#\n# Comentá qué gotcha mitiga cada decisión: (gotcha: <id>).\n`);
  writeFileSync(join(tfDir, 'outputs.tf'), '');
  writeFileSync(
    join(tfDir, 'tests', 'main.tftest.hcl'),
    `# Tests sin credenciales ni recursos reales: mock_provider + command = plan.\n\nmock_provider "${TF_PROVIDER[provider]}" {}\n\nvariables {\n  name = "test"\n}\n\nrun "plan_succeeds" {\n  command = plan\n}\n`,
  );
}

const created = readdirSync(dir);
console.log(`Creado content/patterns/${slug}/ (${created.join(', ')})`);
console.log('Siguientes pasos: completar pattern.yaml, renombrar *.yaml.draft, escribir Terraform y tests, `pnpm validate`.');
