# Guardrail preventivo — AWS
#
# Una Amazon S3 policy de AWS Organizations (declarative policy) que habilita las cuatro opciones de
# S3 Block Public Access, adjunta a la raíz, a OUs o a cuentas. Hay que correrlo con credenciales de la
# cuenta de administración de la organización y con el tipo de política S3_POLICY habilitado.

# "all" habilita las cuatro opciones juntas; no hay forma de elegir cada una por separado
# (gotcha: s3-policy-scope-is-the-exception). IgnorePublicAcls y RestrictPublicBuckets son las que
# neutralizan lo que ya existe (gotcha: s3-policy-ignores-existing-public-access-does-not-remove-it).
resource "aws_organizations_policy" "block_public_access" {
  name        = "${var.name}-s3-block-public-access"
  description = "Habilita las cuatro opciones de S3 Block Public Access en las cuentas alcanzadas."
  # S3_POLICY figura entre los valores válidos de `type` en la documentación del provider y `terraform validate`
  # lo acepta; la lista de la regla de tflint-ruleset-aws 0.36.0 todavía no lo incluye.
  # tflint-ignore: aws_organizations_policy_invalid_type
  type = "S3_POLICY"

  content = jsonencode({
    s3_attributes = {
      public_access_block_configuration = {
        "@@assign" = "all"
      }
    }
  })

  tags = var.tags
}

# Una cuenta que necesita buckets públicos queda fuera eligiendo los targets: la excepción es de alcance,
# por OU o por cuenta (gotcha: s3-policy-scope-is-the-exception).
resource "aws_organizations_policy_attachment" "this" {
  for_each = var.target_ids

  policy_id = aws_organizations_policy.block_public_access.id
  target_id = each.value
}
