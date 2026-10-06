import { describe, expect, it } from 'vitest';
import { crossValidate, type ContentData } from '../src/lib/content.ts';
import { registryUrl, splitRef } from '../src/lib/terraform-map.ts';
import { site } from '../src/lib/site.ts';

describe('mapa Terraform', () => {
  it('arma la URL del registry según el provider', () => {
    expect(registryUrl('azurerm_private_endpoint')).toBe('https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint');
    expect(registryUrl('aws_s3_bucket')).toBe('https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket');
    expect(registryUrl('google_storage_bucket.lifecycle_rule')).toBe('https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket');
    expect(registryUrl('google_project_iam_member')).toMatch(/\/resources\/google_project_iam$/);
    expect(registryUrl('google_storage_bucket_iam_member')).toMatch(/\/resources\/storage_bucket_iam$/);
    expect(splitRef('google_dns_managed_zone.forwarding_config')).toEqual({ resource: 'google_dns_managed_zone', block: 'forwarding_config' });
  });

  it('valida prefijos, match y notas', () => {
    const data: ContentData = {
      capabilities: [], patterns: [], exams: [], concepts: [],
      terraformMap: {
        providers: { azurerm: '~> 5.8', aws: '~> 6.67', google: '~> 8.6' },
        verified_at: '2026-10-06',
        entries: [
          { id: 'a', title: { es: 'a' }, match: 'one-to-one', resources: { azure: ['aws_vpc'], aws: ['aws_vpc'], gcp: ['google_compute_network'] }, sources: [] },
          { id: 'b', title: { es: 'b' }, match: 'partial', resources: { azure: ['azurerm_subnet'], aws: [], gcp: ['google_compute_subnetwork'] }, sources: [] },
          { id: 'c', title: { es: 'c' }, match: 'gap', capability: 'nope', resources: { azure: ['azurerm_subnet'], aws: ['aws_subnet'], gcp: ['google_compute_subnetwork'] }, sources: [] },
        ],
      },
    };
    const errs = crossValidate(data, new Date('2026-10-06')).filter((i) => i.level === 'error').map((i) => i.message).join('\n');
    expect(errs).toMatch(/a: "aws_vpc" no es un recurso de azure/);
    expect(errs).toMatch(/b: aws sin recursos: usá match gap/);
    expect(errs).toMatch(/b: match partial necesita notes/);
    expect(errs).toMatch(/c: match gap pero las tres nubes tienen recursos/);
    expect(errs).toMatch(/c: capability inexistente "nope"/);
  });

  it('el contenido publicado referencia capabilities y conceptos que existen', () => {
    const caps = new Set(site.capabilities.map((c) => c.id));
    const concepts = new Set(site.concepts.map((c) => c.id));
    for (const e of site.terraformMap!.entries) {
      if (e.capability) expect(caps).toContain(e.capability);
      if (e.concept) expect(concepts).toContain(e.concept);
    }
  });
});
