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

/** Recorrido predefinido sobre el diagrama (ej. "camino del token"): roles en orden. */
export const PatternPath = z.strictObject({
  id: slug,
  label: Localized,
  roles: z.array(slug).min(2),
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
  paths: z.array(PatternPath).default([]),
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
    /**
     * `partial`: cumple el rol pero no es un equivalente directo (otro alcance u otro modelo).
     * Se dibuja punteado y exige `notes` que explique la diferencia.
     */
    equivalence: z.enum(['full', 'partial']).default('full'),
    /** "Venís de <nube>": qué cambia para quien conoce el servicio de esa nube en este rol. */
    from: z.partialRecord(Provider, Localized).optional(),
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
  /** Roles del patrón a los que aplica (para el diagrama interactivo). */
  roles: z.array(slug).default([]),
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

// ---------------------------------------------------------------------------
// Conceptos (content/concepts/*.yaml): estructura de cada nube, no servicios
// ---------------------------------------------------------------------------

export const CONCEPT_CATEGORIES = ['organization', 'identity', 'networking', 'operations'] as const;

export const ConceptTerm = z.strictObject({
  term: Text,
  docs: SourceUrl,
});

export const ConceptProviderEntry = z.strictObject({
  /** Los nombres que usa esa nube, de mayor a menor alcance si es una jerarquía. */
  terms: z.array(ConceptTerm).min(1),
  explanation: Localized,
});

export const Concept = z.strictObject({
  id: slug,
  category: z.enum(CONCEPT_CATEGORIES),
  name: Localized,
  description: Localized,
  providers: z.strictObject({ azure: ConceptProviderEntry, aws: ConceptProviderEntry, gcp: ConceptProviderEntry }),
  /** Dónde se rompe la analogía. Cada una con fuente oficial. */
  caveats: z.array(z.strictObject({ text: Localized, sources: z.array(SourceUrl).min(1) })).default([]),
  verified_at: z.iso.date(),
});
export type Concept = z.infer<typeof Concept>;

// ---------------------------------------------------------------------------
// Mapa de recursos Terraform (content/terraform-map.yaml)
// ---------------------------------------------------------------------------

/** `tipo_de_recurso` o `tipo_de_recurso.bloque` (cuando en una nube es un bloque, no un recurso). */
export const TerraformRef = z.string().regex(/^(azurerm|aws|google)_[a-z0-9_]+(\.[a-z0-9_]+)?$/, 'recurso de Terraform (azurerm_*, aws_*, google_*) o recurso.bloque');

export const TF_PREFIX = { azure: 'azurerm_', aws: 'aws_', gcp: 'google_' } as const satisfies Record<Provider, string>;

export const TerraformMapEntry = z.strictObject({
  id: slug,
  title: Localized,
  /** Capability o concepto del sitio con el que se relaciona (opcional). */
  capability: slug.optional(),
  concept: slug.optional(),
  /** one-to-one: mismo alcance y forma; partial: hay que pensar distinto; gap: alguna nube no tiene recurso. */
  match: z.enum(['one-to-one', 'partial', 'gap']),
  resources: z.strictObject({ azure: z.array(TerraformRef), aws: z.array(TerraformRef), gcp: z.array(TerraformRef) }),
  notes: Localized.optional(),
  sources: z.array(SourceUrl).default([]),
});
export type TerraformMapEntry = z.infer<typeof TerraformMapEntry>;

export const TerraformMap = z.strictObject({
  /** Versiones de provider contra las que se validaron los nombres (las mismas de los módulos). */
  providers: z.strictObject({ azurerm: z.string(), aws: z.string(), google: z.string() }),
  verified_at: z.iso.date(),
  entries: z.array(TerraformMapEntry).min(1),
});
export type TerraformMap = z.infer<typeof TerraformMap>;

// ---------------------------------------------------------------------------
// Precios de lista (content/pricing.yaml + content/prices.json)
// ---------------------------------------------------------------------------

/** Unidad normalizada de un precio. `hour` se lleva a mes con 730 h. */
export const PRICE_UNITS = ['hour', 'month', 'gb-month'] as const;
export const PriceUnit = z.enum(PRICE_UNITS);
export type PriceUnit = z.infer<typeof PriceUnit>;
export const HOURS_PER_MONTH = 730;

/** Igualdad exacta sobre campos de la API (Azure Retail Prices / atributos del Price List de AWS). */
const MatchFields = z.record(z.string().min(1), z.string().min(1));

export const PriceMeter = z.strictObject({
  id: slug,
  provider: Provider,
  label: Localized,
  unit: PriceUnit,
  /** Cómo encontrarlo en la API de precios de su nube. Debe resolver a exactamente un precio. */
  azure: z.strictObject({ service: z.string().min(1), match: MatchFields }).optional(),
  aws: z.strictObject({ offer: z.string().min(1), match: MatchFields }).optional(),
  gcp: z.strictObject({ service: z.string().min(1), description: z.string().min(1) }).optional(),
  /**
   * Precio cargado a mano desde la página oficial, para cuando la API no está disponible
   * (el Billing Catalog de GCP pide API key). Si la API responde, gana la API.
   */
  manual: z.strictObject({ unit_price: z.number().nonnegative(), verified_at: z.iso.date(), source: SourceUrl }).optional(),
  /** Página oficial de precios del servicio. */
  docs: SourceUrl,
});
export type PriceMeter = z.infer<typeof PriceMeter>;

/** Un componente del piso mensual: `count` instancias (o GB, si la unidad es gb-month) del meter. */
export const FloorItem = z.strictObject({ meter: slug, count: z.number().positive() });
export type FloorItem = z.infer<typeof FloorItem>;

export const Pricing = z.strictObject({
  /** Una región comparable por nube: los pisos solo se comparan en estas. */
  regions: z.strictObject({ azure: z.string(), aws: z.string(), gcp: z.string() }),
  meters: z.array(PriceMeter).min(1),
  /**
   * Piso mensual por patrón y nube: lo que se paga con cero tráfico, con la configuración
   * por default del módulo Terraform. Lista vacía = sin costo fijo.
   */
  floors: z.record(slug, z.strictObject({ azure: z.array(FloorItem), aws: z.array(FloorItem), gcp: z.array(FloorItem) })),
});
export type Pricing = z.infer<typeof Pricing>;

/** Salida del job de precios (`pnpm prices:fetch`). No se edita a mano. */
export const PriceEntry = z.strictObject({
  unit_price: z.number().nonnegative(),
  unit: PriceUnit,
  source: z.enum(['api', 'manual']),
  as_of: z.iso.date(),
  /** Qué devolvió la API, para auditar (SKU, meter, unidad original). */
  ref: z.string(),
});
export type PriceEntry = z.infer<typeof PriceEntry>;

export const Prices = z.strictObject({
  generated_at: z.iso.datetime(),
  currency: z.literal('USD'),
  prices: z.record(slug, PriceEntry),
});
export type Prices = z.infer<typeof Prices>;

// ---------------------------------------------------------------------------
// Matriz de decisión (content/decisions/*.yaml)
// ---------------------------------------------------------------------------

export const MEETS = ['yes', 'no', 'partial'] as const;

export const DecisionOption = z.strictObject({
  id: slug,
  provider: Provider,
  /** Servicio + SKU/tier/modo concreto ("Service Bus Premium", "SQS FIFO"). */
  name: Text,
  /** Qué cumple. `partial` exige nota. */
  meets: z.record(slug, z.union([z.enum(['yes', 'no']), z.strictObject({ value: z.enum(MEETS), note: Localized })])),
  notes: Localized.optional(),
  /** Piso mensual de esta opción (meters de content/pricing.yaml). Vacío = sin costo fijo. */
  floor: z.array(FloorItem).default([]),
  sources: z.array(SourceUrl).min(1),
});
export type DecisionOption = z.infer<typeof DecisionOption>;

export const Decision = z.strictObject({
  id: slug,
  capability: slug,
  title: Localized,
  intro: Localized,
  requirements: z.array(z.strictObject({ id: slug, label: Localized, hint: Localized.optional() })).min(2),
  options: z.array(DecisionOption).min(3),
  verified_at: z.iso.date(),
});
export type Decision = z.infer<typeof Decision>;
