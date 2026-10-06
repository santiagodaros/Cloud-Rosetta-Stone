# Hacktoberfest en Letra Chica

Guía corta para sumar un PR que cuente y que se mergee rápido. Las reglas del evento cambian de un año al
otro: confirmá las vigentes en [hacktoberfest.com](https://hacktoberfest.com).

## Por dónde empezar

| Si tenés… | Tomá un issue con | Ejemplos |
|---|---|---|
| 30 minutos | `freshness` | Re-verificar los gotchas de una nube en un patrón ([#3](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/3), [#4](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/4), [#5](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/5)) |
| 1 hora | `dictionary` | Una capability nueva: registro de contenedores, conectividad híbrida, data warehouse ([#7](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/7), [#8](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/8), [#9](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/9)) |
| 1 hora | `translation` | Revisión nativa del inglés ([#6](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/6)) |
| Una tarde | `pattern` | Una nube de un patrón nuevo: hub-and-spoke, secretos, egress/NAT ([#15](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/15), [#16](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/16), [#17](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/17)) |
| Experiencia en AWS o GCP | `community` | Ser reviewer de esa nube ([#18](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues/18)) |

Todos los issues abiertos para el evento tienen la etiqueta `hacktoberfest`. Comentá en el issue antes de
arrancar para que no lo tomen dos personas.

## Qué hace que un PR se mergee

- **Fuente oficial en cada gotcha** (dominios en `OFFICIAL_SOURCE_HOSTS`, `src/lib/schema.ts`) y
  `verified_at` con el día en que la leíste.
- **`pnpm verify` en verde** antes de abrir el PR. Si tocás Terraform: `terraform fmt`, `validate` y
  `terraform test` en el módulo.
- **Un tema por PR.** Un gotcha, una capability o una nube de un patrón.
- **Sin datos reales:** ni clientes, ni IDs de tenant, suscripción, cuenta o proyecto, ni IPs públicas.

## Qué no vamos a mergear

- Cambios cosméticos sin issue (espacios, sinónimos, reordenar listas).
- Gotchas sin fuente oficial o con fuente de blog o foro.
- Texto generado que nadie verificó contra la documentación: el CI no detecta eso, el review sí.

## Para maintainers

- El repo necesita el topic `hacktoberfest` (Settings → General → Topics) para participar.
- Los PRs válidos se aceptan con merge, aprobación o la etiqueta `hacktoberfest-accepted`, según las reglas
  del año. Los inválidos llevan `invalid` o `spam`.
