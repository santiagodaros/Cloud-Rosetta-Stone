/**
 * Carga y validación del contenido (`content/`).
 *
 * Dos niveles de validación:
 *  1. Estructural (Zod, por archivo) → `schema.ts`.
 *  2. Referencial (entre archivos) → `crossValidate`: roles, capabilities, bindings,
 *     Terraform presente, gotchas únicos, fechas.
 *
 * El sitio y el validador de CI usan exactamente esta función, así que lo que pasa
 * CI es lo que se publica.
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { parse as parseYaml } from 'yaml';
import { z } from 'zod';
import {
  Capability,
  Concept,
  type Exam,
  ExamCatalog,
  Implementation,
  Pattern,
  PROVIDERS,
  type Provider,
  TerraformMap,
  TF_PREFIX,
} from './schema.ts';

export type Issue = { level: 'error' | 'warning'; file: string; message: string };

export type TerraformFile = { name: string; code: string };
export type TerraformModule = {
  dir: string;
  files: TerraformFile[];
  /** `name → constraint` leído de `required_providers`. */
  providers: Record<string, string>;
  hasTests: boolean;
};

export type PatternBundle = {
  pattern: Pattern;
  implementations: Partial<Record<Provider, Implementation>>;
  terraform: Partial<Record<Provider, TerraformModule>>;
};

export type ContentData = {
  capabilities: Capability[];
  patterns: PatternBundle[];
  exams: Exam[];
  concepts: Concept[];
  terraformMap?: TerraformMap;
};

export type ExamStatus = 'active' | 'retiring' | 'retired';

/** Estado derivado de `retires_on` (último día en que se puede rendir). */
export function examStatus(exam: Exam, today = new Date()): ExamStatus {
  if (!exam.retires_on) return 'active';
  return daysSince(exam.retires_on, today) > 0 ? 'retired' : 'retiring';
}

export type LoadResult = ContentData & { issues: Issue[] };

/** Días a partir de los cuales un gotcha se considera "a re-verificar". */
export const STALE_AFTER_DAYS = 180;

const TF_DISPLAY_ORDER = ['main.tf', 'variables.tf', 'outputs.tf', 'versions.tf'];

function readYaml<T>(file: string, schema: z.ZodType<T>, root: string, issues: Issue[]): T | undefined {
  let raw: unknown;
  try {
    raw = parseYaml(readFileSync(file, 'utf8'));
  } catch (e) {
    issues.push({ level: 'error', file: relative(root, file), message: `YAML inválido: ${(e as Error).message}` });
    return undefined;
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    issues.push({ level: 'error', file: relative(root, file), message: z.prettifyError(parsed.error) });
    return undefined;
  }
  return parsed.data;
}

const listDirs = (dir: string) =>
  existsSync(dir) ? readdirSync(dir).filter((d) => statSync(join(dir, d)).isDirectory()).sort() : [];

const listFiles = (dir: string, ext: string) =>
  existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith(ext)).sort() : [];

/** Extrae `required_providers` sin parsear HCL completo (alcanza para mostrar versiones). */
export function parseRequiredProviders(hcl: string): Record<string, string> {
  const out: Record<string, string> = {};
  const start = hcl.search(/required_providers\s*\{/);
  if (start === -1) return out;
  // Las entradas (`aws = { source = ..., version = ... }`) no tienen llaves anidadas.
  const entry = /(\w+)\s*=\s*\{[^{}]*?version\s*=\s*"([^"]+)"[^{}]*\}/g;
  for (const m of hcl.slice(start).matchAll(entry)) out[m[1]] = m[2];
  return out;
}

function loadTerraform(dir: string): TerraformModule | undefined {
  if (!existsSync(dir)) return undefined;
  const names = listFiles(dir, '.tf').sort(
    (a, b) => (TF_DISPLAY_ORDER.indexOf(a) + 1 || 99) - (TF_DISPLAY_ORDER.indexOf(b) + 1 || 99),
  );
  const files = names.map((name) => ({ name, code: readFileSync(join(dir, name), 'utf8') }));
  const providers = Object.assign({}, ...files.map((f) => parseRequiredProviders(f.code)));
  return { dir, files, providers, hasTests: listFiles(join(dir, 'tests'), '.tftest.hcl').length > 0 };
}

export function loadContent(root = process.cwd()): LoadResult {
  const issues: Issue[] = [];
  const contentDir = join(root, 'content');

  const capabilities = listFiles(join(contentDir, 'capabilities'), '.yaml')
    .map((f) => readYaml(join(contentDir, 'capabilities', f), Capability, root, issues))
    .filter((c): c is Capability => c !== undefined);

  const patterns: PatternBundle[] = [];
  for (const slug of listDirs(join(contentDir, 'patterns'))) {
    const dir = join(contentDir, 'patterns', slug);
    const patternFile = join(dir, 'pattern.yaml');
    if (!existsSync(patternFile)) {
      issues.push({ level: 'error', file: relative(root, dir), message: 'falta pattern.yaml' });
      continue;
    }
    const pattern = readYaml(patternFile, Pattern, root, issues);
    if (!pattern) continue;
    if (pattern.id !== slug) {
      issues.push({ level: 'error', file: relative(root, patternFile), message: `id "${pattern.id}" debe coincidir con la carpeta "${slug}"` });
    }
    const bundle: PatternBundle = { pattern, implementations: {}, terraform: {} };
    for (const provider of PROVIDERS) {
      const implFile = join(dir, `${provider}.yaml`);
      if (existsSync(implFile)) {
        const impl = readYaml(implFile, Implementation, root, issues);
        if (impl) bundle.implementations[provider] = impl;
      }
      const tf = loadTerraform(join(dir, 'terraform', provider));
      if (tf) bundle.terraform[provider] = tf;
    }
    patterns.push(bundle);
  }

  const examsFile = join(contentDir, 'exams.yaml');
  const catalog = existsSync(examsFile) ? readYaml(examsFile, ExamCatalog, root, issues) : undefined;
  if (!existsSync(examsFile)) issues.push({ level: 'error', file: 'content/exams.yaml', message: 'falta el catálogo de exámenes' });

  const concepts = listFiles(join(contentDir, 'concepts'), '.yaml')
    .map((f) => readYaml(join(contentDir, 'concepts', f), Concept, root, issues))
    .filter((c): c is Concept => c !== undefined);

  const mapFile = join(contentDir, 'terraform-map.yaml');
  const terraformMap = existsSync(mapFile) ? readYaml(mapFile, TerraformMap, root, issues) : undefined;

  const data = { capabilities, patterns, exams: catalog?.exams ?? [], concepts, terraformMap };
  issues.push(...crossValidate(data));
  return { ...data, issues };
}

/** Validaciones entre archivos. Pura (sin I/O) para poder testearla. */
export function crossValidate(data: ContentData, today = new Date()): Issue[] {
  const issues: Issue[] = [];
  const capIds = new Set<string>();
  for (const c of data.capabilities) {
    if (capIds.has(c.id)) issues.push({ level: 'error', file: `content/capabilities/${c.id}.yaml`, message: `capability duplicada: ${c.id}` });
    capIds.add(c.id);
  }

  const conceptIds = new Set<string>();
  for (const c of data.concepts) {
    const file = `content/concepts/${c.id}.yaml`;
    if (conceptIds.has(c.id)) issues.push({ level: 'error', file, message: `concepto duplicado: ${c.id}` });
    conceptIds.add(c.id);
    const age = daysSince(c.verified_at, today);
    if (age < 0) issues.push({ level: 'error', file, message: 'verified_at está en el futuro' });
    else if (age > STALE_AFTER_DAYS) issues.push({ level: 'warning', file, message: `verificado hace ${age} días (> ${STALE_AFTER_DAYS}): re-verificar` });
  }

  if (data.terraformMap) {
    const MAP_FILE = 'content/terraform-map.yaml';
    const mapErr = (message: string) => issues.push({ level: 'error', file: MAP_FILE, message });
    const ids = new Set<string>();
    for (const e of data.terraformMap.entries) {
      if (ids.has(e.id)) mapErr(`entrada duplicada: ${e.id}`);
      ids.add(e.id);
      if (e.capability && !capIds.has(e.capability)) mapErr(`${e.id}: capability inexistente "${e.capability}"`);
      if (e.concept && !conceptIds.has(e.concept)) mapErr(`${e.id}: concepto inexistente "${e.concept}"`);
      for (const p of PROVIDERS) {
        for (const r of e.resources[p]) if (!r.startsWith(TF_PREFIX[p])) mapErr(`${e.id}: "${r}" no es un recurso de ${p} (${TF_PREFIX[p]}*)`);
      }
      const empty = PROVIDERS.filter((p) => e.resources[p].length === 0);
      if (e.match === 'gap' && empty.length === 0) mapErr(`${e.id}: match gap pero las tres nubes tienen recursos`);
      if (e.match !== 'gap' && empty.length > 0) mapErr(`${e.id}: ${empty.join(', ')} sin recursos: usá match gap`);
      if (e.match !== 'one-to-one' && !e.notes) mapErr(`${e.id}: match ${e.match} necesita notes que expliquen la diferencia`);
    }
    const age = daysSince(data.terraformMap.verified_at, today);
    if (age > STALE_AFTER_DAYS) issues.push({ level: 'warning', file: MAP_FILE, message: `verificado hace ${age} días: re-verificar` });
  }

  const EXAMS_FILE = 'content/exams.yaml';
  const exams = new Map<string, Exam>();
  for (const e of data.exams) {
    if (exams.has(e.code)) issues.push({ level: 'error', file: EXAMS_FILE, message: `examen duplicado: ${e.code}` });
    exams.set(e.code, e);
  }
  for (const e of data.exams) {
    if (e.replaced_by && !exams.has(e.replaced_by)) {
      issues.push({ level: 'error', file: EXAMS_FILE, message: `${e.code}: replaced_by "${e.replaced_by}" no está en el catálogo` });
    }
    if (e.replaced_by && !e.retires_on) {
      issues.push({ level: 'error', file: EXAMS_FILE, message: `${e.code}: tiene replaced_by pero no retires_on` });
    }
  }

  for (const { pattern, implementations, terraform } of data.patterns) {
    const base = `content/patterns/${pattern.id}`;
    const err = (file: string, message: string) => issues.push({ level: 'error', file: `${base}/${file}`, message });
    const warn = (file: string, message: string) => issues.push({ level: 'warning', file: `${base}/${file}`, message });

    const roleIds = new Set<string>();
    for (const role of pattern.roles) {
      if (roleIds.has(role.id)) err('pattern.yaml', `rol duplicado: ${role.id}`);
      roleIds.add(role.id);
      if (role.kind === 'capability' && !capIds.has(role.capability)) {
        err('pattern.yaml', `el rol "${role.id}" referencia la capability inexistente "${role.capability}" (creá content/capabilities/${role.capability}.yaml)`);
      }
    }
    for (const e of pattern.edges) {
      for (const end of [e.from, e.to]) if (!roleIds.has(end)) err('pattern.yaml', `edge ${e.from}→${e.to}: rol inexistente "${end}"`);
    }
    if (!pattern.title.en) warn('pattern.yaml', 'falta traducción al inglés del título');
    const pathIds = new Set<string>();
    for (const path of pattern.paths) {
      if (pathIds.has(path.id)) err('pattern.yaml', `recorrido duplicado: ${path.id}`);
      pathIds.add(path.id);
      for (const r of path.roles) if (!roleIds.has(r)) err('pattern.yaml', `recorrido "${path.id}": rol inexistente "${r}"`);
      for (let k = 1; k < path.roles.length; k++) {
        const [a, b] = [path.roles[k - 1], path.roles[k]];
        if (!pattern.edges.some((e) => (e.from === a && e.to === b) || (e.from === b && e.to === a))) {
          err('pattern.yaml', `recorrido "${path.id}": no hay edge entre "${a}" y "${b}"`);
        }
      }
    }

    const capabilityRoles = pattern.roles.filter((r) => r.kind === 'capability').map((r) => r.id);

    for (const provider of PROVIDERS) {
      const impl = implementations[provider];
      const file = `${provider}.yaml`;
      if (!impl) {
        (pattern.status === 'published' ? err : warn)(file, `falta la implementación de ${provider}`);
        continue;
      }
      if (impl.provider !== provider) err(file, `provider "${impl.provider}" no coincide con el nombre del archivo`);

      for (const roleId of capabilityRoles) {
        if (!(roleId in impl.bindings)) err(file, `falta binding para el rol "${roleId}" (usá { gap: ... } si no hay equivalente)`);
      }
      for (const [roleId, b] of Object.entries(impl.bindings)) {
        if (!roleIds.has(roleId)) err(file, `binding para rol inexistente "${roleId}"`);
        else if (!capabilityRoles.includes(roleId)) err(file, `el rol "${roleId}" es un actor: no lleva binding`);
        if ('service' in b) {
          if (b.equivalence === 'partial' && !b.notes) err(file, `binding "${roleId}": equivalence partial necesita notes que expliquen la diferencia`);
          if (b.from && provider in b.from) err(file, `binding "${roleId}": from.${provider} no tiene sentido en la propia nube`);
        }
      }

      const gotchaIds = new Set<string>();
      for (const g of impl.gotchas) {
        if (gotchaIds.has(g.id)) err(file, `gotcha duplicado: ${g.id}`);
        gotchaIds.add(g.id);
        const age = daysSince(g.verified_at, today);
        if (age < 0) err(file, `gotcha "${g.id}": verified_at está en el futuro`);
        else if (age > STALE_AFTER_DAYS) warn(file, `gotcha "${g.id}" verificado hace ${age} días (> ${STALE_AFTER_DAYS}): re-verificar`);
        if (!g.title.en || !g.body.en) warn(file, `gotcha "${g.id}": falta traducción al inglés`);
        for (const r of g.roles) {
          if (!capabilityRoles.includes(r)) err(file, `gotcha "${g.id}": el rol "${r}" no existe o es un actor`);
        }
        for (const code of g.exams) {
          const exam = exams.get(code);
          if (!exam) {
            err(file, `gotcha "${g.id}": el examen "${code}" no está en ${EXAMS_FILE}`);
          } else if (exam.provider !== provider) {
            err(file, `gotcha "${g.id}": ${code} es un examen de ${exam.provider}, no de ${provider}`);
          } else if (examStatus(exam, today) === 'retired') {
            const hint = exam.replaced_by ? ` (reemplazo: ${exam.replaced_by})` : '';
            warn(file, `gotcha "${g.id}": ${code} se retiró el ${exam.retires_on}; re-etiquetar${hint}`);
          }
        }
      }

      const tf = terraform[provider];
      if (!tf) {
        (pattern.status === 'published' ? err : warn)(`terraform/${provider}`, 'falta el módulo de Terraform');
      } else {
        if (!tf.files.some((f) => f.name === 'main.tf')) err(`terraform/${provider}`, 'falta main.tf');
        if (!tf.hasTests) err(`terraform/${provider}`, 'falta tests/*.tftest.hcl (al menos un test con mock_provider)');
        if (Object.keys(tf.providers).length === 0) err(`terraform/${provider}`, 'required_providers sin versión pinneada');
      }
    }
  }
  return issues;
}

export function daysSince(isoDate: string, today = new Date()): number {
  const d = new Date(`${isoDate}T00:00:00Z`).getTime();
  const t = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  return Math.floor((t - d) / 86_400_000);
}

/** Para el sitio: falla el build si hay errores, así nunca se publica contenido inválido. */
export function loadContentOrThrow(root = process.cwd()): ContentData {
  const { issues, ...data } = loadContent(root);
  const errors = issues.filter((i) => i.level === 'error');
  if (errors.length) {
    throw new Error(`Contenido inválido (corré \`pnpm validate\`):\n${errors.map((e) => `  ${e.file}: ${e.message}`).join('\n')}`);
  }
  return data;
}
