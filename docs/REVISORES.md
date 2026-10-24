# Guía para revisores de nube

Letra Chica vale lo que vale su verificación. Hoy los gotchas los verifica solo el mantenedor, y la pre-verificación
automática encontró que cerca de un tercio tenía alguna afirmación que su fuente no respaldaba
([`PRE-VERIFICACION.md`](./PRE-VERIFICACION.md)). Un revisor es la segunda mirada que falta, sobre todo en AWS y GCP.

## Qué se pide

- **Experiencia real** con la nube que revisás (no hace falta ser experto en las tres).
- **30 minutos por mes** alcanzan. Revisá lo que puedas, empezando por lo más severo.
- **Leer la fuente oficial**, no revisar de memoria. Si el gotcha dice algo que la fuente no dice, eso es un hallazgo.

## Qué recibís

- Tu usuario de GitHub en la tarjeta de cada gotcha que revises ("✓ revisado por @vos").
- Tu nombre en `CODEOWNERS` para esa nube: GitHub te pide revisión en los PR que tocan sus archivos.

## Cómo revisar un gotcha (5 pasos)

1. **Elegí uno** de la cola: el issue "Cola de revisión por nube" o `pnpm freshness --review`. Vienen por nube y con
   los más severos primero (seguridad, IAM, red).
2. **Leé el texto** del gotcha en `content/patterns/<patrón>/<nube>.yaml` (clave `gotchas`) y abrí **cada fuente**.
3. **Chequeá cada afirmación** contra el texto de la fuente:
   - ¿Cada número, límite, nombre de atributo, código de error o "siempre/nunca" está en la fuente?
   - ¿El título dice más de lo que respalda el cuerpo?
   - ¿Sigue siendo cierto hoy? (nombres de servicios y defaults cambian.)
   - ¿La comparación con otra nube la respalda alguna fuente de ese mismo gotcha?
4. **Corregí en un PR**:
   - Si falta respaldo: agregá la fuente oficial que lo diga textual, o recortá la frase.
   - Si está desactualizado: corregí el texto y la fuente.
   - Si está bien: no cambies el texto.
5. **Firmá**: en cada gotcha que revisaste, actualizá `verified_at` a la fecha de hoy (el día que leíste la fuente) y
   agregá `verified_by: <tu usuario de GitHub>`, sin `@`. Corré `pnpm validate`.

Un gotcha que revisaste y encontraste correcto también se firma. Revisar sin cambiar nada es una contribución válida.

## Reglas editoriales (resumen; completas en CONTRIBUTING)

- **Fuente oficial obligatoria.** Blogs, foros y repost.aws no respaldan; sirven para descubrir un problema.
- **Sin ganador.** Si una nube es más barata o simple en un punto, decí qué cuesta en otro.
- **Sin datos reales de clientes, cuentas ni tenants** en ejemplos, issues ni capturas.
- **Un hallazgo no es una falla tuya.** Si no podés confirmar algo, dejalo marcado en el PR en vez de adivinar.

## Qué es lo más útil de revisar

1. Gotchas de severidad `security`, `iam` y `networking`: un error ahí cuesta más.
2. Los **patrones en borrador** (`status: draft`): `app-secrets`, `controlled-egress` y `hub-and-spoke`. No se
   publican hasta tener revisión humana, así que tu firma es lo que los destraba.
3. Afirmaciones sobre **costos**: las páginas de precios cambian y a veces no se pueden leer automáticamente.

## Cómo sumarte

Abrí el issue **"Quiero revisar una nube"** (nube y experiencia, sin nombres de clientes). Al incorporarte, se
descomenta tu nube en `.github/CODEOWNERS` y empezás por la cola.

## Para el mantenedor

- Al sumar un revisor: descomentar su nube en `.github/CODEOWNERS` y reemplazar el placeholder.
- Los textos de convocatoria están en [`launch/convocatoria-revisores.md`](./launch/convocatoria-revisores.md).
- Un patrón en borrador se publica cuando: el CI del Terraform está verde, hay al menos una revisión humana de su nube
  por gotcha y están cargados sus pisos de costo y su mapa de Terraform.
