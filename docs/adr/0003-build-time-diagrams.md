# ADR 0003 — Diagramas generados en build time (ELK → SVG), no React Flow

- **Estado:** aceptada (2026-10-06)
- **Reemplaza:** `@xyflow/react` con nodos/edges en JSONB por nube

## Contexto

El spec guardaba coordenadas de nodos por nube. Eso obliga a cada contribuidor a dibujar a mano y produce
diagramas inconsistentes entre nubes, justo donde el valor es compararlos.

## Decisión

- La **topología se define una vez** por patrón (`roles` + `edges` en `pattern.yaml`).
- Cada nube solo declara qué servicio implementa cada rol (`bindings`).
- El layout lo calcula ELK en build time, **una sola vez** con el alto de nodo máximo entre nubes, y se
  renderiza como SVG estático. Los roles sin equivalente se dibujan punteados en rojo.

## Consecuencias

- **+** Diagramas idénticos en posición: el ojo compara solo lo que cambia.
- **+** Cero JS en el cliente, se ve sin JavaScript, sirve para OG images (Fase 1).
- **+** Contribuir un diagrama = escribir 5 líneas de YAML.
- **−** Sin pan/zoom/drag. Si hace falta interacción, se agrega una isla encima del mismo layout.
