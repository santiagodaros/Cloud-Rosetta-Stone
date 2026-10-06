import type { Locale, Provider, Severity, Text } from './schema.ts';
import { LOCALES } from './schema.ts';

export { LOCALES };
export type { Locale };

/** Texto localizado con fallback a español (idioma primario del contenido). */
export const t = (text: Text | undefined, lang: Locale): string =>
  text === undefined ? '' : typeof text === 'string' ? text : (text[lang] ?? text.es);

/** true si el texto se está mostrando en fallback (para marcarlo en la UI). */
export const isFallback = (text: Text | undefined, lang: Locale) =>
  !!text && typeof text !== 'string' && lang !== 'es' && !text[lang];

export const PROVIDER_META: Record<Provider, { name: string; short: string; color: string }> = {
  azure: { name: 'Microsoft Azure', short: 'Azure', color: 'var(--c-azure)' },
  aws: { name: 'Amazon Web Services', short: 'AWS', color: 'var(--c-aws)' },
  gcp: { name: 'Google Cloud', short: 'GCP', color: 'var(--c-gcp)' },
};

const UI = {
  es: {
    tagline: 'Traducí arquitecturas entre Azure, AWS y GCP: dónde se rompe la analogía, con Terraform verificado.',
    patterns: 'Patrones',
    dictionary: 'Diccionario',
    contribute: 'Contribuir',
    problem: 'Problema',
    topology: 'Topología',
    topologyNote: 'La topología es la misma en todas las nubes; lo que cambia es con qué se implementa cada rol.',
    implementation: 'Implementación',
    role: 'Rol',
    service: 'Servicio',
    gap: 'Sin equivalente directo',
    gotchas: 'Letra chica',
    sources: 'Fuentes',
    verified: (d: number) => (d === 0 ? 'verificado hoy' : `verificado hace ${d} día${d === 1 ? '' : 's'}`),
    stale: 're-verificar',
    exams: 'Suma para',
    cost: 'Modelo de costo',
    scalesToZero: { yes: 'Escala a cero', no: 'No escala a cero', partial: 'Escala a cero parcial' },
    fixedCost: 'Costo fijo aunque no haya tráfico',
    noFixedCost: 'Sin costo fijo',
    terraform: 'Terraform',
    terraformChecks: 'fmt · validate · tflint · checkov · terraform test',
    copy: 'Copiar',
    copied: 'Copiado',
    compare: 'Comparar',
    allThree: 'Las tres',
    vs: 'vs',
    caveats: 'Dónde se rompe la analogía',
    untranslated: 'sin traducir',
    disclaimer:
      'Proyecto comunitario independiente. No está afiliado a Microsoft, Amazon ni Google. Verificá siempre contra la documentación oficial enlazada.',
    license: 'Código MIT · Contenido CC BY-SA 4.0',
    openData: 'Datos abiertos (JSON)',
    severity: {
      security: 'Seguridad',
      iam: 'IAM',
      networking: 'Red',
      cost: 'Costo',
      reliability: 'Confiabilidad',
      operations: 'Operación',
    } satisfies Record<Severity, string>,
    gotchaCount: (n: number) => `${n} gotcha${n === 1 ? '' : 's'}`,
    patternCount: (n: number) => `${n} patrón${n === 1 ? '' : 'es'}`,
    ogKicker: 'Comparación de arquitectura',
    ogFooter: (n: number) => `${n} gotchas con fuente oficial · Terraform testeado`,
    search: 'Buscar',
    searchPlaceholder: 'Buscá un servicio, un gotcha o un examen…',
    methodology: 'Cómo verificamos',
    copyLink: 'Copiar link a este gotcha',
    linkCopied: 'Link copiado',
    capabilityCount: (n: number) => `${n} capabilities`,
  },
  en: {
    tagline: 'Translate architectures across Azure, AWS and GCP: where the analogy breaks, with verified Terraform.',
    patterns: 'Patterns',
    dictionary: 'Dictionary',
    contribute: 'Contribute',
    problem: 'Problem',
    topology: 'Topology',
    topologyNote: 'The topology is the same on every cloud; what changes is what implements each role.',
    implementation: 'Implementation',
    role: 'Role',
    service: 'Service',
    gap: 'No direct equivalent',
    gotchas: 'Fine print',
    sources: 'Sources',
    verified: (d: number) => (d === 0 ? 'verified today' : `verified ${d} day${d === 1 ? '' : 's'} ago`),
    stale: 're-verify',
    exams: 'Helps with',
    cost: 'Cost model',
    scalesToZero: { yes: 'Scales to zero', no: "Doesn't scale to zero", partial: 'Partially scales to zero' },
    fixedCost: 'Fixed cost even with zero traffic',
    noFixedCost: 'No fixed cost',
    terraform: 'Terraform',
    terraformChecks: 'fmt · validate · tflint · checkov · terraform test',
    copy: 'Copy',
    copied: 'Copied',
    compare: 'Compare',
    allThree: 'All three',
    vs: 'vs',
    caveats: 'Where the analogy breaks',
    untranslated: 'untranslated',
    disclaimer:
      'Independent community project. Not affiliated with Microsoft, Amazon or Google. Always verify against the linked official documentation.',
    license: 'Code MIT · Content CC BY-SA 4.0',
    openData: 'Open data (JSON)',
    severity: {
      security: 'Security',
      iam: 'IAM',
      networking: 'Networking',
      cost: 'Cost',
      reliability: 'Reliability',
      operations: 'Operations',
    } satisfies Record<Severity, string>,
    gotchaCount: (n: number) => `${n} gotcha${n === 1 ? '' : 's'}`,
    patternCount: (n: number) => `${n} pattern${n === 1 ? '' : 's'}`,
    ogKicker: 'Architecture comparison',
    ogFooter: (n: number) => `${n} gotchas with official sources · Tested Terraform`,
    search: 'Search',
    searchPlaceholder: 'Search a service, a gotcha or an exam…',
    methodology: 'How we verify',
    copyLink: 'Copy link to this gotcha',
    linkCopied: 'Link copied',
    capabilityCount: (n: number) => `${n} capabilities`,
  },
} as const;

export const ui = (lang: Locale) => UI[lang];
