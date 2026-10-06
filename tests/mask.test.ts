import { describe, expect, it } from 'vitest';
import { loadContentOrThrow } from '../src/lib/content.ts';
import { MASK, maskProviderTerms } from '../src/lib/mask.ts';

describe('maskProviderTerms', () => {
  it('tapa marcas, productos e identificadores, no conceptos', () => {
    expect(maskProviderTerms('En Azure, Service Bus usa peek-lock; en AWS, SQS usa visibility timeout.')).toBe(
      `En ${MASK}, ${MASK} usa peek-lock; en ${MASK}, ${MASK} usa visibility timeout.`,
    );
    expect(maskProviderTerms('Deny por aws:SourceVpce y s3:PutObject')).toBe(`Deny por ${MASK}:SourceVpce y ${MASK}:PutObject`);
    expect(maskProviderTerms('api@proyecto.iam.gserviceaccount.com')).toBe(MASK);
    expect(maskProviderTerms('azure_pg_admin y google_sql_user')).toBe(`${MASK} y ${MASK}`);
  });

  it('no confunde palabras en español con productos', () => {
    expect(maskProviderTerms('el mensaje entra a la cola y acá se procesa')).toBe('el mensaje entra a la cola y acá se procesa');
  });

  it('"VPC" queda visible: existe en AWS y en GCP', () => {
    expect(maskProviderTerms('dentro de la VPC')).toBe('dentro de la VPC');
  });

  it('ningún gotcha publicado deja ver el nombre de la nube', () => {
    const brand = /\b(Azure|AWS|Amazon|Google|GCP|Microsoft)\b/i;
    const leaks: string[] = [];
    for (const { pattern, implementations } of loadContentOrThrow().patterns) {
      for (const impl of Object.values(implementations)) {
        for (const g of impl?.gotchas ?? []) {
          for (const text of [g.title.es, g.body.es, g.title.en ?? '', g.body.en ?? '']) {
            const masked = maskProviderTerms(text);
            if (brand.test(masked)) leaks.push(`${pattern.id}/${impl!.provider}/${g.id}: ${masked.match(brand)![0]}`);
          }
        }
      }
    }
    expect(leaks).toEqual([]);
  });
});
