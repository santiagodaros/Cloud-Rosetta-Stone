# ADR 0004 — Pipeline de calidad de Terraform sin credenciales

- **Estado:** aceptada (2026-10-06)

## Contexto

Un snippet de IaC que no compila o que es inseguro destruye la credibilidad del proyecto. La plataforma no
puede tocar nubes reales (guardrail), y CI tampoco debería necesitar credenciales.

## Decisión

Cada módulo en `content/patterns/*/terraform/<nube>/` pasa en CI:

1. `terraform fmt -check`
2. `terraform init -backend=false` + `terraform validate` (schema real del provider pinneado)
3. `terraform test` con `mock_provider` y `command = plan` (aserciones sobre lo que el patrón promete)
4. `tflint` con el ruleset de la nube (`.tflint/<nube>.hcl`)
5. `checkov`: cero fallas; cada excepción va en el código como `#checkov:skip=ID:motivo`

Renovate abre PRs de providers; si CI se pone rojo, ese PR es el aviso de que el snippet quedó viejo.

## Consecuencias

- **+** Detecta drift de schema (ejemplo real de Fase 0: azurerm 5 cambió
  `azurerm_private_dns_zone_virtual_network_link`, lo detectó `validate`).
- **+** Las excepciones de seguridad quedan documentadas y visibles en el snippet publicado.
- **−** `mock_provider` no detecta errores de API en apply (nombres inválidos, cuotas, regiones).
  Mitigación opcional (Fase 4): deploy real nightly en sandbox con OIDC.
- **−** checkov no siempre conoce atributos nuevos (ej.: evalúa `public_network_access_enabled`, deprecado
  en azurerm 5). Se documenta como skip con el motivo.
