/** Utilidades del mapa de recursos Terraform (F4-15). */

const PROVIDER_OF = { azurerm: 'azurerm', aws: 'aws', google: 'google' } as const;

/** Páginas del registry de google que conservan el prefijo (recursos de Resource Manager). */
const GOOGLE_PREFIXED = new Set(['google_project', 'google_folder', 'google_service_account', 'google_project_service', 'google_project_iam_custom_role']);

/** `azurerm_storage_account` → página del registry; `google_storage_bucket.lifecycle_rule` → la del recurso. */
export function registryUrl(ref: string): string {
  const { resource } = splitRef(ref);
  const prefix = resource.split('_')[0] as keyof typeof PROVIDER_OF;
  // _iam_member / _iam_binding / _iam_policy comparten una sola página por recurso.
  const base = resource.replace(/_iam_(member|binding|policy)$/, '_iam');
  const page = prefix === 'google' && (GOOGLE_PREFIXED.has(base) || base === 'google_project_iam') ? base : base.slice(prefix.length + 1);
  return `https://registry.terraform.io/providers/hashicorp/${PROVIDER_OF[prefix]}/latest/docs/resources/${page}`;
}

/** Recurso y bloque opcional (`google_storage_bucket.lifecycle_rule`). */
export function splitRef(ref: string): { resource: string; block?: string } {
  const [resource, block] = ref.split('.');
  return { resource, block };
}
