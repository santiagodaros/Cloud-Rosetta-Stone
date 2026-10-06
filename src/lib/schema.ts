/**
 * Schema canónico del contenido de Letra Chica.
 *
 * Es la única fuente de verdad: lo usan el sitio (build), el validador de CI
 * (`pnpm validate`) y el dataset abierto (`/api/v1/*.json`). Si cambiás algo acá,
 * actualizá `docs/CONTENT-MODEL.md`.
 */
import { z } from 'zod';

export const PROVIDERS = ['azure', 'aws', 'gcp'] as const;
export const Provider = z.enum(PROVIDERS);
export type Provider = z.infer<typeof Provider>;

export const LOCALES = ['es', 'en'] as const;
export type Locale = (typeof LOCALES)[number];

/** Texto localizado. Español es obligatorio (idioma primario del proyecto). */
export const Localized = z.strictObject({
  es: z.string().min(1),
  en: z.string().min(1).optional(),
});
export type Localized = z.infer<typeof Localized>;

/**
 * Nombre de producto o configuración: string si es igual en todos los idiomas
 * ("Amazon S3", "ipv4_enabled = false"), o Localized si contiene texto traducible.
 */
export const Text = z.union([z.string().min(1), Localized]);
export type Text = z.infer<typeof Text>;

const slug = z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'debe ser kebab-case');

/**
 * Dominios aceptados como "fuente oficial". Un gotcha sin fuente oficial no se publica:
 * blogs y foros sirven para descubrir un problema, no para respaldarlo.
 */
export const OFFICIAL_SOURCE_HOSTS = [
  'learn.microsoft.com',
  'azure.microsoft.com',
  'docs.aws.amazon.com',
  'aws.amazon.com',
  'repost.aws',
  'cloud.google.com',
  'docs.cloud.google.com',
  'registry.terraform.io',
  'developer.hashicorp.com',
  // El IdP de los patrones de CI/CD: su documentación es la fuente oficial del formato de los tokens.
  'docs.github.com',
] as const;

export const SourceUrl = z.url({ protocol: /^https$/ }).refine(
  (u) => {
    const host = new URL(u).hostname;
    return OFFICIAL_SOURCE_HOSTS.some((h) => host === h || host.endsWith(`.${h}`));
  },
  { message: `la fuente debe ser documentación oficial (${OFFICIAL_SOURCE_HOSTS.join(', ')})` },
);

export const CATEGORIES = ['compute-web', 'async-event', 'storage-data', 'networking', 'identity', 'governance', 'observability'] as const;
export const Category = z.enum(CATEGORIES);

// ---------------------------------------------------------------------------
// Capabilities: diccionario hub-and-spoke (capability canónica → servicio por nube)
// ---------------------------------------------------------------------------

export const CapabilityImplementation = z.strictObject({
  service: Text,
  docs: SourceUrl,
  notes: Localized.optional(),
});

export const CapabilityProviderEntry = z.union([
  z.strictObject({ services: z.array(CapabilityImplementation).min(1) }),
  /** No hay equivalente directo: el hueco es información, no un error. */
  z.strictObject({ gap: Localized, docs: SourceUrl.optional() }),
]);

export const Capability = z.strictObject({
  id: slug,
  category: Category,
  name: Localized,
  description: Localized,
  providers: z.strictObject({
    azure: CapabilityProviderEntry,
    aws: CapabilityProviderEntry,
    gcp: CapabilityProviderEntry,
  }),
  /** Dónde se rompe la analogía a nivel concepto (independiente de un patrón). */
  caveats: z.array(Localized).default([]),
});
export type Capability = z.infer<typeof Capability>;

// ---------------------------------------------------------------------------
// Patterns: topología abstracta definida UNA vez, compartida por todas las nubes
// ---------------------------------------------------------------------------

export const Role = z.discriminatedUnion('kind', [
  z.strictObject({ id: slug, kind: z.literal('actor'), label: Localized }),
  z.strictObject({ id: slug, kind: z.literal('capability'), label: Localized, capability: slug }),
]);
export type Role = z.infer<typeof Role>;

export const Edge = z.strictObject({
  from: slug,
  to: slug,
  label: Localized.optional(),
});

export const Pattern = z.strictObject({
  id: slug,
  status: z.enum(['draft', 'published']),
  category: Category,
  title: Localized,
  summary: Localized,
  problem: Localized,
  roles: z.array(Role).min(2),
  edges: z.array(Edge).min(1),
  tags: z.array(slug).default([]),
});
export type Pattern = z.infer<typeof Pattern>;

// ---------------------------------------------------------------------------
// Implementation: cómo se resuelve el patrón en una nube concreta
// ---------------------------------------------------------------------------

export const Binding = z.union([
  z.strictObject({
    service: Text,
    /** SKU/tier/config que hace que el patrón funcione (ej. "Premium", "Gateway endpoint"). */
    config: Text.optional(),
    notes: Localized.optional(),
  }),
  z.strictObject({ gap: Localized }),
]);
export type Binding = z.infer<typeof Binding>;

export const SEVERITIES = ['security', 'iam', 'networking', 'cost', 'reliability', 'operations'] as const;
export const Severity = z.enum(SEVERITIES);
export type Severity = z.infer<typeof Severity>;

// ---------------------------------------------------------------------------
// Exámenes de certificación (content/exams.yaml)
// ---------------------------------------------------------------------------

export const ExamCode = z.string().regex(/^[A-Z0-9-]+$/, 'código de examen en mayúsculas (AZ-104, SAA-C03, ACE)');

export const EXAM_LEVELS = ['foundational', 'associate', 'professional', 'expert', 'specialty'] as const;

export const Exam = z.strictObject({
  code: ExamCode,
  provider: Provider,
  /** Nombre oficial del examen, tal cual lo publica el proveedor (no se traduce). */
  name: z.string().min(1),
  /** Certificación que otorga (o de la que forma parte). */
  certification: z.string().min(1),
  level: z.enum(EXAM_LEVELS),
  /** Página oficial (study guide o página de la certificación). */
  url: SourceUrl,
  /**
   * Último día en que se puede rendir. El estado se deriva de esta fecha
   * (retirado si ya pasó, "se retira" si es futura), así nadie tiene que acordarse de cambiarlo.
   */
  retires_on: z.iso.date().optional(),
  /** Código del examen que lo reemplaza (debe existir en el catálogo). */
  replaced_by: ExamCode.optional(),
});
export type Exam = z.infer<typeof Exam>;

export const ExamCatalog = z.strictObject({
  /** Fecha en que se verificó el catálogo completo contra las páginas oficiales. */
  verified_at: z.iso.date(),
  exams: z.array(Exam).min(1),
});
export type ExamCatalog = z.infer<typeof ExamCatalog>;

export const Gotcha = z.strictObject({
  id: slug,
  severity: Severity,
  title: Localized,
  body: Localized,
  sources: z.array(SourceUrl).min(1, 'cada gotcha necesita al menos una fuente oficial'),
  verified_at: z.iso.date(),
  /** Códigos de examen donde este conocimiento suma (AZ-104, SAA-C03, ACE...). Deben existir en `content/exams.yaml`. */
  exams: z.array(ExamCode).default([]),
});
export type Gotcha = z.infer<typeof Gotcha>;

export const Cost = z.strictObject({
  scales_to_zero: z.enum(['yes', 'no', 'partial']),
  /** Componentes que generan costo fijo aunque haya cero tráfico. */
  fixed_cost_drivers: z.array(Localized).default([]),
  notes: Localized,
});

export const Implementation = z.strictObject({
  provider: Provider,
  bindings: z.record(slug, Binding),
  gotchas: z.array(Gotcha).min(1),
  cost: Cost,
});
export type Implementation = z.infer<typeof Implementation>;
