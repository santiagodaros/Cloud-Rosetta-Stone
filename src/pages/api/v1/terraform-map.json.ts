import type { APIRoute } from 'astro';
import { envelope, jsonResponse } from '../../../lib/dataset.ts';
import { site } from '../../../lib/site.ts';
import { registryUrl } from '../../../lib/terraform-map.ts';

/** Dataset abierto: mapa de recursos Terraform entre azurerm, aws y google. */
export const GET: APIRoute = () =>
  jsonResponse(
    envelope({
      providers: site.terraformMap?.providers,
      verified_at: site.terraformMap?.verified_at,
      entries: (site.terraformMap?.entries ?? []).map((e) => ({
        ...e,
        registry: Object.fromEntries(Object.values(e.resources).flat().map((r) => [r, registryUrl(r)])),
      })),
    }),
  );
