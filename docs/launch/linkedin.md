# LinkedIn — posts de lanzamiento

Tres posts (expectativa → lanzamiento → letra chica), dos variantes cada uno: **A** abre con una
historia/dolor, **B** abre con datos concretos. Elegí una por post, no mezcles.

Reglas para los tres:
- El link va **en el primer comentario**, no en el cuerpo (LinkedIn penaliza links externos en el post).
- Pegá el link en un borrador antes de publicar para verificar que levanta la imagen OG.
- Máximo 3–4 hashtags. Nada de nombres de clientes ni capturas con datos de tenants.
- Respondé todos los comentarios de las primeras 2 horas: es lo que más mueve el alcance.

Imágenes en [`assets/`](./assets/). Links con `{SITE}` = `BRAND.site` en `src/lib/brand.ts`.

---

## Post 1 — Expectativa (semana −1)

**Imagen:** `assets/comparador-ttl-azure-vs-aws.png`

### Variante A — dolor

```text
"S3 es Blob Storage". Todas las tablas comparativas dicen lo mismo.

Ninguna te avisa que en Azure el prefijo de una lifecycle policy tiene que incluir el nombre del contenedor. Si copiás el filtro "incoming/" que te funcionaba en S3, la policy se crea sin error… y nunca borra nada.

O que en Google Cloud los buckets vienen con soft delete de 7 días activado: un archivo que vive una hora te lo cobran una hora más siete días.

Ese tipo de diferencia no está en una tabla de equivalencias. Está en la letra chica de la documentación, repartida en tres sitios distintos.

Estoy armando una herramienta abierta para juntarla: patrones de arquitectura completos comparados lado a lado entre Azure, AWS y GCP, cada diferencia con su fuente oficial y fecha de verificación, y Terraform que compila y pasa checks de seguridad.

Pregunta para los que trabajan en más de una nube: ¿qué diferencia te costó más cara la primera vez que te la cruzaste?

#Multicloud #Azure #AWS #GoogleCloud
```

### Variante B — datos

```text
Leí la documentación oficial de Azure, AWS y Google Cloud para cinco patrones de arquitectura comunes y encontré 74 diferencias que no aparecen en ninguna tabla de "servicios equivalentes".

Tres ejemplos:

→ En Azure, el filtro de una lifecycle policy empieza con el nombre del contenedor. El mismo filtro que funciona en S3 no borra nada, y no da error.
→ En Google Cloud, los buckets traen soft delete de 7 días activado. Para datos efímeros eso puede multiplicar el costo.
→ En AWS, un Deny por aws:SourceVpce en la bucket policy también te bloquea a vos y a tu pipeline.

Lo estoy convirtiendo en una herramienta abierta: cada patrón comparado en las tres nubes, cada diferencia con fuente oficial y fecha, y Terraform testeado.

¿Qué patrón te gustaría ver comparado primero?

#Multicloud #Azure #AWS #GoogleCloud
```

---

## Post 2 — Lanzamiento (día L)

**Imagen:** `assets/web-api-tres-nubes.png` (o dejá que el link muestre la OG image)
**Primer comentario:** `{SITE}/es/` + `BRAND.repo`

### Variante A — por qué lo hice

```text
Lancé Letra Chica: la letra chica del multicloud.

Trabajo todos los días con Azure y cada vez que tengo que diseñar algo en AWS o GCP pasa lo mismo: la tabla de equivalencias me dice qué servicio usar, pero no qué se rompe cuando traduzco la arquitectura.

Letra Chica compara patrones completos, no servicios sueltos:

🔹 Web API privada Zero Trust con PostgreSQL sin contraseñas
🔹 Worker asíncrono que escala a cero, con dead-letter
🔹 Ingesta privada de objetos con expiración
🔹 Despliegue desde CI sin secretos (OIDC)
🔹 DNS privado híbrido entre on-premises y la nube

Para cada uno, en Azure, AWS y GCP: el diagrama, qué implementa cada pieza, el modelo de costo, la letra chica (74 diferencias, cada una con fuente oficial y fecha de verificación) y el Terraform.

Ese Terraform no es decorativo: en cada cambio pasa validate, tests sin credenciales, tflint y checkov. Si mañana un provider cambia un atributo, el CI lo marca.

Es gratis, sin cuentas, en español e inglés, y el contenido es abierto (CC BY-SA). Las contribuciones más valiosas no son patrones nuevos: son re-verificar lo que ya está.

Link en el primer comentario.

#Multicloud #Azure #AWS #GoogleCloud
```

### Variante B — qué tiene

```text
Lancé Letra Chica, una herramienta abierta para traducir arquitecturas entre Azure, AWS y Google Cloud.

Lo que tiene hoy:
→ 5 patrones completos comparados en las 3 nubes
→ 74 diferencias documentadas, cada una con fuente oficial y fecha de verificación
→ 15 módulos de Terraform que pasan validate, tests, tflint y checkov en cada cambio
→ Diccionario de 28 servicios con los huecos explícitos (sí: a veces no hay equivalente)
→ Español e inglés, sin cuentas, sin costo, datos abiertos en JSON

Lo que no es: un ranking de nubes. Si algo es más simple en una, el texto dice qué se paga en otra.

Una de mis favoritas: en Cloud SQL para PostgreSQL, el usuario IAM de una Service Account va sin el sufijo ".gserviceaccount.com". Si lo creás con el email completo, el login falla con un error que parece de permisos.

Link en el primer comentario. Si encontrás algo desactualizado, abrí un issue: es la contribución que más vale.

#Multicloud #Azure #AWS #GoogleCloud
```

---

## Post 3 — La letra chica (día L+3 a L+5)

Copy **corregido** respecto del plan original: Peek-Lock **no** garantiza exactly-once (ver
análisis §3.3 y el gotcha `peek-lock-is-at-least-once`).

**Imagen:** `assets/gotcha-peek-lock.png`
**Primer comentario:** `{SITE}/es/patterns/async-worker/azure-vs-aws/`

### Variante A — mito

```text
"Service Bus tiene Peek-Lock, así que procesa exactamente una vez". No.

Tres cosas que aparecen al mover un worker de SQS a Service Bus (o al revés):

1. Entrega. Peek-Lock y el visibility timeout de SQS son el mismo mecanismo: at-least-once. Si el worker muere después de procesar y antes de completar, el mensaje vuelve. La duplicate detection de Service Bus deduplica envíos, no procesamientos. En las dos nubes, el worker tiene que ser idempotente.

2. Red privada. Un Private Endpoint en Service Bus exige el tier Premium, que se cobra por messaging unit aunque no haya mensajes. En AWS, un interface endpoint de SQS también tiene cargo por hora, pero no te obliga a cambiar de tier.

3. Dead-letter. En Service Bus es una subcola automática que ocupa la cuota de la cola: si nadie la vacía, la cola principal termina rechazando envíos. En SQS es otra cola, y en colas Standard el mensaje vence según cuándo entró a la cola original; si la DLQ retiene lo mismo que el origen, los mensajes pueden desaparecer casi enseguida.

Está comparado lado a lado (también contra Pub/Sub), con las fuentes y el Terraform. Link en el primer comentario.

#Azure #AWS #Messaging #AI200
```

### Variante B — checklist

```text
Checklist antes de migrar un worker entre SQS, Service Bus y Pub/Sub:

☐ ¿Es idempotente? Peek-Lock, visibility timeout y ack deadline son at-least-once. Pub/Sub tiene exactly-once, pero solo en suscripciones pull.
☐ ¿Necesitás red privada? En Service Bus eso es Premium (costo fijo por messaging unit). En SQS no cambia el tier.
☐ ¿Quién vacía la dead-letter? En Service Bus ocupa la cuota de la cola. En SQS Standard la DLQ tiene que retener más que la cola original. En Pub/Sub un dead-letter topic sin suscripción pierde los mensajes.
☐ ¿El escalado tiene identidad? En Container Apps, el scaler de KEDA consulta la cola por su cuenta: si deshabilitaste las claves, la regla de escalado también tiene que usar la identidad administrada.
☐ ¿El timeout está alineado? En Lambda, el visibility timeout de la cola tiene que ser al menos 6 veces el timeout de la función.

Cada punto tiene su fuente oficial en el link del primer comentario.

#Azure #AWS #GoogleCloud #Messaging
```

---

## Versión en inglés del lanzamiento (opcional, para tu red internacional)

```text
I launched Letra Chica ("the fine print" in Spanish): an open tool that translates architecture patterns across Azure, AWS and Google Cloud.

Not a service-equivalence table. Full patterns, compared side by side: diagram, what implements each role, cost model, and the fine print, meaning 74 documented differences, each with an official source and a verification date. Plus Terraform that passes validate, mock-provider tests, tflint and checkov on every change.

Spanish first, English included, no accounts, open data.

Link in the first comment. If you find something outdated, open an issue: re-verifying is the most valuable contribution.

#Multicloud #Azure #AWS #GoogleCloud
```
