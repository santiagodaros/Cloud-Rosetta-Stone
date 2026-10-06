import { describe, expect, it } from 'vitest';
import { crossValidate, daysSince, examStatus, loadContent, parseRequiredProviders, type ContentData } from '../src/lib/content.ts';
import { Gotcha, SourceUrl } from '../src/lib/schema.ts';
import { wrap } from '../src/lib/diagram.ts';

describe('contenido real del repo', () => {
  it('no tiene errores de validación', () => {
    const { issues } = loadContent();
    expect(issues.filter((i) => i.level === 'error')).toEqual([]);
  });
});

describe('SourceUrl', () => {
  it('acepta documentación oficial', () => {
    expect(SourceUrl.safeParse('https://learn.microsoft.com/azure/storage/').success).toBe(true);
    expect(SourceUrl.safeParse('https://docs.cloud.google.com/storage/docs/soft-delete').success).toBe(true);
  });

  it('rechaza blogs, http y dominios parecidos', () => {
    expect(SourceUrl.safeParse('https://medium.com/some-post').success).toBe(false);
    expect(SourceUrl.safeParse('http://learn.microsoft.com/azure').success).toBe(false);
    expect(SourceUrl.safeParse('https://learn.microsoft.com.evil.example/').success).toBe(false);
  });
});

describe('Gotcha', () => {
  const base = {
    id: 'x',
    severity: 'cost',
    title: { es: 't' },
    body: { es: 'b' },
    sources: ['https://docs.aws.amazon.com/x'],
    verified_at: '2026-01-01',
  };

  it('exige al menos una fuente', () => {
    expect(Gotcha.safeParse({ ...base, sources: [] }).success).toBe(false);
  });

  it('exige fecha ISO', () => {
    expect(Gotcha.safeParse({ ...base, verified_at: '01/01/2026' }).success).toBe(false);
  });
});

describe('crossValidate', () => {
  const minimal = (): ContentData => ({
    capabilities: [
      {
        id: 'queue',
        category: 'async-event',
        name: { es: 'Cola' },
        description: { es: 'd' },
        providers: { azure: { gap: { es: 'no' } }, aws: { gap: { es: 'no' } }, gcp: { gap: { es: 'no' } } },
        caveats: [],
      },
    ],
    patterns: [
      {
        pattern: {
          id: 'p',
          status: 'draft',
          category: 'async-event',
          title: { es: 'P', en: 'P' },
          summary: { es: 's' },
          problem: { es: 'p' },
          roles: [
            { id: 'client', kind: 'actor', label: { es: 'c' } },
            { id: 'q', kind: 'capability', capability: 'queue', label: { es: 'q' } },
          ],
          edges: [{ from: 'client', to: 'q' }],
          paths: [],
          tags: [],
        },
        implementations: {},
        terraform: {},
      },
    ],
    exams: [
      { code: 'SAA-C03', provider: 'aws', name: 'n', certification: 'c', level: 'associate', url: 'https://aws.amazon.com/x' },
      { code: 'AZ-104', provider: 'azure', name: 'n', certification: 'c', level: 'associate', url: 'https://learn.microsoft.com/x' },
      { code: 'OLD-01', provider: 'aws', name: 'n', certification: 'c', level: 'associate', url: 'https://aws.amazon.com/x', retires_on: '2026-01-31', replaced_by: 'SAA-C03' },
    ],
  });
  const errors = (data: ContentData, today = new Date('2026-10-06')) =>
    crossValidate(data, today).filter((i) => i.level === 'error').map((i) => i.message);

  it('un draft sin implementaciones solo genera warnings', () => {
    expect(errors(minimal())).toEqual([]);
  });

  it('un patrón publicado exige las tres nubes', () => {
    const d = minimal();
    d.patterns[0].pattern.status = 'published';
    expect(errors(d)).toEqual(['falta la implementación de azure', 'falta la implementación de aws', 'falta la implementación de gcp']);
  });

  it('detecta capabilities y roles inexistentes', () => {
    const d = minimal();
    d.patterns[0].pattern.roles[1] = { id: 'q', kind: 'capability', capability: 'nope', label: { es: 'q' } };
    d.patterns[0].pattern.edges.push({ from: 'q', to: 'ghost' });
    expect(errors(d).join('\n')).toMatch(/capability inexistente "nope"[\s\S]*rol inexistente "ghost"/);
  });

  it('exige binding para cada rol de capability y prohíbe bindings en actores', () => {
    const d = minimal();
    d.patterns[0].implementations.aws = {
      provider: 'aws',
      bindings: { client: { service: 'x', equivalence: 'full' } },
      gotchas: [
        { id: 'g', severity: 'cost', title: { es: 't' }, body: { es: 'b' }, sources: ['https://docs.aws.amazon.com/x'], verified_at: '2026-10-01', exams: [], roles: [] },
      ],
      cost: { scales_to_zero: 'yes', fixed_cost_drivers: [], notes: { es: 'n' } },
    };
    const msgs = errors(d).join('\n');
    expect(msgs).toMatch(/falta binding para el rol "q"/);
    expect(msgs).toMatch(/"client" es un actor/);
  });

  it('marca gotchas viejos como warning y fechas futuras como error', () => {
    const d = minimal();
    const gotcha = (id: string, verified_at: string) => ({
      id, severity: 'cost' as const, title: { es: 't', en: 't' }, body: { es: 'b', en: 'b' },
      sources: ['https://docs.aws.amazon.com/x'], verified_at, exams: [], roles: [],
    });
    d.patterns[0].implementations.aws = {
      provider: 'aws',
      bindings: { q: { service: 'SQS', equivalence: 'full' } },
      gotchas: [gotcha('old', '2025-01-01'), gotcha('future', '2027-01-01')],
      cost: { scales_to_zero: 'yes', fixed_cost_drivers: [], notes: { es: 'n' } },
    };
    const issues = crossValidate(d, new Date('2026-10-06'));
    expect(issues.some((i) => i.level === 'warning' && /"old" verificado hace/.test(i.message))).toBe(true);
    expect(issues.some((i) => i.level === 'error' && /"future".*futuro/.test(i.message))).toBe(true);
  });

  it('valida los exámenes de cada gotcha contra el catálogo', () => {
    const d = minimal();
    d.patterns[0].implementations.aws = {
      provider: 'aws',
      bindings: { q: { service: 'SQS', equivalence: 'full' } },
      gotchas: [
        {
          id: 'g', severity: 'cost', title: { es: 't', en: 't' }, body: { es: 'b', en: 'b' },
          sources: ['https://docs.aws.amazon.com/x'], verified_at: '2026-10-01', exams: ['SAA-C03', 'NOPE-01', 'AZ-104', 'OLD-01'], roles: [],
        },
      ],
      cost: { scales_to_zero: 'yes', fixed_cost_drivers: [], notes: { es: 'n' } },
    };
    const issues = crossValidate(d, new Date('2026-10-06'));
    const errs = issues.filter((i) => i.level === 'error').map((i) => i.message).join('\n');
    expect(errs).toMatch(/"NOPE-01" no está en content\/exams.yaml/);
    expect(errs).toMatch(/AZ-104 es un examen de azure, no de aws/);
    expect(errs).not.toMatch(/SAA-C03/);
    expect(issues.some((i) => i.level === 'warning' && /OLD-01 se retiró.*reemplazo: SAA-C03/.test(i.message))).toBe(true);
  });

  it('exige que replaced_by exista en el catálogo', () => {
    const d = minimal();
    d.exams[2].replaced_by = 'GHOST-01';
    expect(errors(d)).toEqual(['OLD-01: replaced_by "GHOST-01" no está en el catálogo']);
  });
});

describe('examStatus', () => {
  const e = { code: 'X-01', provider: 'aws' as const, name: 'n', certification: 'c', level: 'associate' as const, url: 'https://aws.amazon.com/x' };
  it('deriva el estado de retires_on (último día rendible)', () => {
    const today = new Date('2026-10-06');
    expect(examStatus(e, today)).toBe('active');
    expect(examStatus({ ...e, retires_on: '2026-10-06' }, today)).toBe('retiring');
    expect(examStatus({ ...e, retires_on: '2026-10-05' }, today)).toBe('retired');
  });
});

describe('crossValidate: diagrama interactivo y nube de origen', () => {
  const base = (): ContentData => ({
    capabilities: [{ id: 'queue', category: 'async-event', name: { es: 'Cola' }, description: { es: 'd' }, providers: { azure: { gap: { es: 'no' } }, aws: { gap: { es: 'no' } }, gcp: { gap: { es: 'no' } } }, caveats: [] }],
    exams: [],
    patterns: [{
      pattern: {
        id: 'p', status: 'draft', category: 'async-event', title: { es: 'P', en: 'P' }, summary: { es: 's' }, problem: { es: 'p' },
        roles: [{ id: 'client', kind: 'actor', label: { es: 'c' } }, { id: 'q', kind: 'capability', capability: 'queue', label: { es: 'q' } }],
        edges: [{ from: 'client', to: 'q' }],
        paths: [{ id: 'flujo', label: { es: 'f' }, roles: ['client', 'ghost'] }],
        tags: [],
      },
      implementations: {
        aws: {
          provider: 'aws',
          bindings: { q: { service: 'SQS', equivalence: 'partial', from: { aws: { es: 'x' } } } },
          gotchas: [{ id: 'g', severity: 'cost', title: { es: 't', en: 't' }, body: { es: 'b', en: 'b' }, sources: ['https://docs.aws.amazon.com/x'], verified_at: '2026-10-01', exams: [], roles: ['client', 'nope'] }],
          cost: { scales_to_zero: 'yes', fixed_cost_drivers: [], notes: { es: 'n' } },
        },
      },
      terraform: {},
    }],
  });

  it('valida recorridos, roles de gotchas, parciales sin nota y from de la propia nube', () => {
    const errs = crossValidate(base(), new Date('2026-10-06')).filter((i) => i.level === 'error').map((i) => i.message).join('\n');
    expect(errs).toMatch(/recorrido "flujo": rol inexistente "ghost"/);
    expect(errs).toMatch(/gotcha "g": el rol "client" no existe o es un actor/);
    expect(errs).toMatch(/gotcha "g": el rol "nope" no existe o es un actor/);
    expect(errs).toMatch(/equivalence partial necesita notes/);
    expect(errs).toMatch(/from\.aws no tiene sentido en la propia nube/);
  });
});

describe('parseRequiredProviders', () => {
  it('lee varias entradas con versión', () => {
    const hcl = `terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
    random = { source = "hashicorp/random", version = ">= 3.0" }
  }
}`;
    expect(parseRequiredProviders(hcl)).toEqual({ aws: '~> 6.67', random: '>= 3.0' });
  });

  it('devuelve vacío sin required_providers', () => {
    expect(parseRequiredProviders('resource "x" "y" {}')).toEqual({});
  });
});

describe('utilidades', () => {
  it('daysSince cuenta días UTC', () => {
    expect(daysSince('2026-10-01', new Date('2026-10-06T23:00:00Z'))).toBe(5);
  });

  it('wrap respeta el ancho sin partir palabras', () => {
    const text = 'Storage Account (StorageV2) + container';
    const lines = wrap(text, 22);
    expect(lines.every((l) => l.length <= 22)).toBe(true);
    expect(lines.join(' ')).toBe(text);
  });
});
