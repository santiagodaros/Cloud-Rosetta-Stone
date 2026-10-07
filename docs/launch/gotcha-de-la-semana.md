# Gotcha de la semana — borradores

> Generado con `pnpm launch:weekly` desde el contenido publicado. Sitio: https://cloud-rosetta-stone.vercel.app
> Antes de publicar: abrí el link, confirmá que el gotcha sigue igual y que la imagen OG se ve bien al pegar el link.

## Semana 1 — Google Cloud: Soft delete viene activo por default (7 días) y encarece los datos efímeros

- Patrón: **Ingesta privada de objetos con expiración (TTL)** · severidad `cost` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/object-storage-ttl/gcp-vs-aws/#gcp-soft-delete-default-7-days
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/object-storage-ttl/gcp-vs-aws.png

```text
Letra chica de Google Cloud #1: Soft delete viene activo por default (7 días) y encarece los datos efímeros

Todos los buckets tienen soft delete con 7 días de retención salvo que lo cambies. Un objeto que vive una hora se cobra esa hora más 7 días de soft delete. En un bucket de ingesta con TTL eso puede multiplicar el costo. El módulo lo pone en 0 por default (deshabilitado) y lo deja como variable explícita.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #GoogleCloud #ACE #PCA
```

Fuentes:
- https://docs.cloud.google.com/storage/docs/soft-delete

## Semana 2 — Azure: En Azure el prefijo del filtro incluye el nombre del contenedor

- Patrón: **Ingesta privada de objetos con expiración (TTL)** · severidad `reliability` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/object-storage-ttl/azure-vs-aws/#azure-prefix-includes-container
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/object-storage-ttl/azure-vs-aws.png

```text
Letra chica de Azure #2: En Azure el prefijo del filtro incluye el nombre del contenedor

prefix_match es "contenedor/ruta", no solo la ruta. Un filtro "incoming/" que en S3 o Cloud Storage funciona, en Azure matchea un contenedor llamado "incoming" y nunca borra nada. El error no es visible: la policy se crea sin fallar.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #Azure #AZ104
```

Fuentes:
- https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-policy-structure

## Semana 3 — Azure: Peek-lock es at-least-once, no exactly-once

- Patrón: **Worker asíncrono con escala a cero y dead-letter** · severidad `reliability` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/async-worker/azure-vs-aws/#azure-peek-lock-is-at-least-once
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/async-worker/azure-vs-aws.png

```text
Letra chica de Azure #3: Peek-lock es at-least-once, no exactly-once

Si el worker muere después de procesar pero antes de completar el mensaje, el lock expira y el mensaje se reentrega. Es el mismo modelo que el visibility timeout de SQS. La duplicate detection de Service Bus deduplica envíos repetidos, no procesamientos: el worker tiene que ser idempotente.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #Azure #AI200 #AZ305
```

Fuentes:
- https://learn.microsoft.com/azure/service-bus-messaging/service-bus-message-loss-and-duplicates

## Semana 4 — Google Cloud: En Postgres, el usuario IAM de una Service Account va sin ".gserviceaccount.com"

- Patrón: **Web API privada Zero Trust con PostgreSQL sin contraseñas** · severidad `iam` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/private-web-api/gcp-vs-aws/#gcp-iam-sa-username-trim
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/private-web-api/gcp-vs-aws.png

```text
Letra chica de Google Cloud #4: En Postgres, el usuario IAM de una Service Account va sin ".gserviceaccount.com"

El nombre del usuario de base es el email de la SA sin el sufijo .gserviceaccount.com (ej. api@proyecto.iam), por el límite de largo de nombres de PostgreSQL. Si lo creás con el email completo, el login falla con un error que parece de permisos.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #GoogleCloud #ACE #PCA
```

Fuentes:
- https://docs.cloud.google.com/sql/docs/postgres/add-manage-iam-users
- https://docs.cloud.google.com/sql/docs/postgres/iam-logins

## Semana 5 — Azure: Por ARM solo podés crear administradores Entra; el rol de la app se crea con SQL

- Patrón: **Web API privada Zero Trust con PostgreSQL sin contraseñas** · severidad `iam` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/private-web-api/azure-vs-aws/#azure-pg-entra-app-role-needs-sql
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/private-web-api/azure-vs-aws.png

```text
Letra chica de Azure #5: Por ARM solo podés crear administradores Entra; el rol de la app se crea con SQL

Terraform/ARM agrega principals Entra como administradores (azure_pg_admin, CREATEROLE, CREATEDB). Para que la identidad de la app tenga permisos mínimos, un admin Entra tiene que ejecutar pgaadauth_create_principal('<nombre>', false, false) y después los GRANT. Para identidades administradas y service principals el nombre es el display name. El módulo deja el SQL exacto como output.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #Azure #AZ305 #SC300
```

Fuentes:
- https://learn.microsoft.com/azure/postgresql/security/security-manage-entra-users

## Semana 6 — AWS: El visibility timeout de la cola tiene que ser al menos 6 veces el timeout de la Lambda

- Patrón: **Worker asíncrono con escala a cero y dead-letter** · severidad `reliability` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/async-worker/aws-vs-azure/#aws-visibility-timeout-6x
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/async-worker/aws-vs-azure.png

```text
Letra chica de AWS #6: El visibility timeout de la cola tiene que ser al menos 6 veces el timeout de la Lambda

Si la función tarda más que el visibility timeout, el mensaje vuelve a ser visible y otra invocación lo toma mientras el primero sigue procesando: duplicados garantizados. AWS recomienda visibility timeout ≥ 6× el timeout de la función. El módulo lo calcula y lo valida.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #AWS #DVAC02 #SAAC03
```

Fuentes:
- https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html
- https://docs.aws.amazon.com/lambda/latest/operatorguide/sqs-retries.html

## Semana 7 — AWS: Un Deny por aws:SourceVpce también te deja afuera a vos

- Patrón: **Ingesta privada de objetos con expiración (TTL)** · severidad `iam` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/object-storage-ttl/aws-vs-azure/#aws-sourcevpce-lockout
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/object-storage-ttl/aws-vs-azure.png

```text
Letra chica de AWS #7: Un Deny por aws:SourceVpce también te deja afuera a vos

Un Deny explícito gana sobre cualquier Allow, incluido el del admin. Si la policy niega todo s3:* fuera del endpoint, la consola y el pipeline de CI (que no están en la VPC) pierden acceso, y podés terminar sin poder editar la propia bucket policy. Este módulo limita el Deny a operaciones de objetos y permite excluir principals de break-glass con aws:PrincipalArn.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #AWS #SAAC03 #SCSC03
```

Fuentes:
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies-vpc-endpoint.html

## Semana 8 — AWS: Fargate en subnet privada sin NAT necesita varios VPC endpoints pagos

- Patrón: **Web API privada Zero Trust con PostgreSQL sin contraseñas** · severidad `cost` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/private-web-api/aws-vs-azure/#aws-fargate-private-needs-endpoints
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/private-web-api/aws-vs-azure.png

```text
Letra chica de AWS #8: Fargate en subnet privada sin NAT necesita varios VPC endpoints pagos

Para bajar la imagen y mandar logs sin salida a internet, la tarea necesita interface endpoints de ECR (api y dkr) y CloudWatch Logs, más el gateway endpoint de S3 (donde ECR guarda las capas). Cada interface endpoint se cobra por hora por AZ: es el costo fijo que en ACA y Cloud Run no existe. La alternativa (NAT Gateway) también tiene cargo por hora y por GB.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #AWS #SAAC03 #ANSC01
```

Fuentes:
- https://repost.aws/knowledge-center/ecs-fargate-tasks-private-subnet
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html

## Semana 9 — Google Cloud: Un dead-letter topic sin suscripción descarta los mensajes

- Patrón: **Worker asíncrono con escala a cero y dead-letter** · severidad `reliability` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/async-worker/gcp-vs-aws/#gcp-dead-letter-topic-needs-subscription
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/async-worker/gcp-vs-aws.png

```text
Letra chica de Google Cloud #9: Un dead-letter topic sin suscripción descarta los mensajes

En Pub/Sub un topic no guarda mensajes por sí mismo: se retienen por suscripción. Si el dead-letter topic no tiene una suscripción creada antes de que lleguen los mensajes, se pierden. El mínimo de intentos antes de reenviar es 5 (máximo 100).

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #GoogleCloud #PDE #PCD
```

Fuentes:
- https://docs.cloud.google.com/pubsub/docs/handling-failures
- https://docs.cloud.google.com/pubsub/docs/dead-letter-topics

## Semana 10 — Azure: Un environment interno no resuelve su propio dominio desde la VNet

- Patrón: **Web API privada Zero Trust con PostgreSQL sin contraseñas** · severidad `networking` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/private-web-api/azure-vs-aws/#azure-aca-internal-needs-private-dns
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/private-web-api/azure-vs-aws.png

```text
Letra chica de Azure #10: Un environment interno no resuelve su propio dominio desde la VNet

Con el ILB, las apps quedan en <app>.<default_domain> pero nadie resuelve ese nombre hasta que creás una zona DNS privada con el nombre del default domain, registros A "*" y "@" al static IP del environment, y la vinculás a las VNets cliente. Sin eso, la API "no existe" aunque esté corriendo.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #Azure #AZ700
```

Fuentes:
- https://learn.microsoft.com/azure/container-apps/private-endpoints-with-dns
- https://learn.microsoft.com/azure/container-apps/waf-app-gateway

## Semana 11 — Azure: Red privada en Service Bus exige Premium, que tiene costo fijo alto

- Patrón: **Worker asíncrono con escala a cero y dead-letter** · severidad `cost` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/async-worker/azure-vs-aws/#azure-sb-private-endpoint-premium
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/async-worker/azure-vs-aws.png

```text
Letra chica de Azure #11: Red privada en Service Bus exige Premium, que tiene costo fijo alto

Private Endpoints, reglas de VNet y CMK solo existen en Premium, que se cobra por messaging unit por hora aunque no haya mensajes. Standard solo admite reglas de IP y además tiene un cargo base mensual. Este patrón usa Standard con autenticación solo Entra ID: si el requisito es red privada, el piso de costo cambia de orden de magnitud. En AWS, SQS admite un interface endpoint sin cambiar de tier.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #Azure #AZ305 #AZ700
```

Fuentes:
- https://learn.microsoft.com/azure/service-bus-messaging/private-link-service
- https://learn.microsoft.com/azure/service-bus-messaging/secure-service-bus
- https://azure.microsoft.com/pricing/details/service-bus/

## Semana 12 — Google Cloud: "Internal" es un control de red; la autenticación es IAM aparte

- Patrón: **Web API privada Zero Trust con PostgreSQL sin contraseñas** · severidad `iam` · verificado hace 1 días
- Link (primer comentario): https://cloud-rosetta-stone.vercel.app/es/patterns/private-web-api/gcp-vs-aws/#gcp-run-internal-is-not-auth
- Imagen: https://cloud-rosetta-stone.vercel.app/og/es/private-web-api/gcp-vs-aws.png

```text
Letra chica de Google Cloud #12: "Internal" es un control de red; la autenticación es IAM aparte

Con ingress internal, Cloud Run rechaza requests que no vengan de VPCs del mismo proyecto (o perímetro de VPC SC) o de otros servicios de Google, aun usando la URL run.app. Pero además, por default exige run.routes.invoke: el cliente tiene que mandar un ID token de una identidad con roles/run.invoker. En ACA y en el ALB interno la red es el único control salvo que agregues auth en la app.

¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.

#Multicloud #GoogleCloud #PCSE #PCA
```

Fuentes:
- https://docs.cloud.google.com/run/docs/securing/ingress
- https://docs.cloud.google.com/run/docs/securing/managing-access
