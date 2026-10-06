/**
 * Enmascarado de nombres de nube y de producto para el modo "¿qué nube es?".
 *
 * Se tapan marcas y nombres de producto (Service Bus, SQS, Cloud Run...), no los
 * conceptos (peek-lock, visibility timeout, soft delete): reconocer de qué nube es
 * un concepto es justamente lo que se practica. "VPC" queda visible a propósito:
 * existe en AWS y en GCP, así que no regala la respuesta.
 */
export const MASK = '▒▒▒';

// Expresiones regulares para dominios e identificadores que delatan la nube.
const RAW: string[] = [
  String.raw`[\w.<>-]*\.windows\.net`,
  String.raw`[\w.<>@-]*\.?gserviceaccount\.com`,
  String.raw`run\.app`,
  String.raw`gcp-sa-[\w-]+`,
];

// Literales, sensibles a mayúsculas ("Entra" sí, "entra" no). Más largos primero.
const TERMS: string[] = [
  // Google Cloud
  'Cloud SQL Auth Proxy',
  'Cloud SQL Language Connectors',
  'Private Google Access',
  'Private Service Connect',
  'Private services access',
  'VPC Service Controls',
  'VPC SC',
  'VPC Network Peering',
  'Cloud Run Jobs',
  'Cloud Run',
  'Cloud SQL',
  'Cloud Storage',
  'Cloud DNS',
  'Cloud NAT',
  'Cloud KMS',
  'Pub/Sub',
  'pubsub',
  'cloudsql',
  'Google Cloud',
  'Google',
  'GCP',
  'GCS',
  'UBLA',
  'PSA',
  // AWS
  'Amazon Web Services',
  'AWS Private CA',
  'CloudWatch Logs',
  'CloudWatch',
  'Secrets Manager',
  'Direct Connect',
  'Route 53',
  'RDS Proxy',
  'Fargate',
  'Lambda',
  'Amazon',
  'AWS',
  'SQS',
  'SNS',
  'S3',
  'ECR',
  'ECS',
  'RDS',
  'ALB',
  'ACM',
  'IAM Identity Center',
  'BucketOwnerEnforced',
  // Azure
  'Microsoft Entra ID',
  'Microsoft Entra',
  'Microsoft.App',
  'Microsoft',
  'Entra ID',
  'Entra',
  'Azure Identity',
  'Azure',
  'Service Bus',
  'Container Apps',
  'App Service',
  'Front Door',
  'Key Vault',
  'PostgreSQL Flexible Server',
  'PostgreSQL Flexible',
  'Private Endpoints',
  'Private Endpoint',
  'azurerm',
  'azuread',
  'ACA',
  'ARM',
  'VNets',
  'VNet',
  // Minúsculas que aparecen en identificadores (aws:SourceVpce, s3:PutObject, roles/cloudsql.client)
  'aws',
  's3',
  'sqs',
];

const escape = (t: string) => t.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
// Bordes por lookaround sobre letras Unicode (\b no se lleva bien con "/", "." ni con "ú").
const W = String.raw`[\p{L}\p{N}_]`;
const PATTERN = new RegExp(`(?<!${W})(?:${[...RAW, ...TERMS.map(escape)].join('|')})(?!${W})`, 'gu');
// Identificadores que llevan el nombre de la nube adentro (azure_pg_admin, google_sql_user).
const IDENTIFIER = /[\w.]*(?:azure|google|aws)[\w.]*/gi;
const RUNS = new RegExp(`${MASK}(?:[\\s/-]*${MASK})+`, 'g');

export function maskProviderTerms(text: string): string {
  return text.replace(PATTERN, MASK).replace(IDENTIFIER, MASK).replace(RUNS, MASK);
}
