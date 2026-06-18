---
name: sql-to-dbml
description: >
  Convierte scripts SQL CREATE TABLE (ANSI genérico) o tablas que se van
  definiendo en código DBML compatible con el plugin de Obsidian "DBML ER
  Diagrams". Usar SIEMPRE que el usuario pida generar o convertir DBML, comparta
  un script de creación de tablas y quiera verlo como diagrama, o diga "pásame el
  dbml de", "convierte este CREATE TABLE a dbml", "genera el dbml de estas
  tablas", "dbml para el plugin", "arma el ERD en dbml", "el diagrama de estas
  tablas", "agrega esta tabla al dbml", "actualiza el dbml con". También al
  construir tablas de forma incremental y querer mantener el bloque dbml al día
  para Obsidian o dbdiagram.io. Activar aunque no se diga literalmente "DBML".
---

# SQL → DBML (para el plugin DBML ER Diagrams)

Genera **DBML** a partir de SQL `CREATE TABLE` (ANSI genérico) o de tablas que se
van definiendo en la conversación. El objetivo es DBML que **renderice bien en el
plugin de Obsidian "DBML ER Diagrams"**, cuyo motor soporta un subconjunto de
DBML. Todo lo que el plugin no dibuja se degrada a una forma equivalente del
subconjunto (ver §6), nunca se emite sintaxis que el plugin no entienda.

## Índice

1. [Modos de uso](#1-modos-de-uso)
2. [Sintaxis DBML objetivo (subset del plugin)](#2-sintaxis-dbml-objetivo-subset-del-plugin)
3. [Mapeo SQL → DBML](#3-mapeo-sql--dbml)
4. [Cardinalidad de relaciones](#4-cardinalidad-de-relaciones)
5. [Identificadores](#5-identificadores)
6. [Degradaciones (solo-subset)](#6-degradaciones-solo-subset)
7. [Convenciones opcionales (off por defecto)](#7-convenciones-opcionales-off-por-defecto)
8. [Modo incremental: preservar el bloque](#8-modo-incremental-preservar-el-bloque)
9. [Formato de entrega](#9-formato-de-entrega)
10. [Checklist antes de entregar](#10-checklist-antes-de-entregar)

Para el detalle fino de cada conversión, leer `references/mapping-ansi-dbml.md`.
Para qué soporta/ignora el plugin exactamente, leer `references/plugin-subset.md`.
Ejemplos entrada→salida en `examples/`.

---

## 1. Modos de uso

**A. Desde script** — el usuario pega uno o varios `CREATE TABLE` (y opcional
`ALTER TABLE ... ADD CONSTRAINT FOREIGN KEY`). Parsear todo el lote, resolver las
FKs (incluidas las definidas por `ALTER`), emitir el bloque DBML completo.

**B. Incremental** — el usuario va describiendo o agregando tablas y quiere
mantener un bloque dbml actualizado. Agregar solo las tablas/relaciones nuevas y
**preservar el bloque existente** tal cual (ver §8). No reordenar ni reescribir lo
previo.

Si el lote mezcla varios dialectos o trae sintaxis ambigua, asumir ANSI/SQL
estándar y señalar al final lo que se interpretó.

---

## 2. Sintaxis DBML objetivo (subset del plugin)

Emitir **únicamente** estas construcciones:

```dbml
Table nombre_tabla [headercolor: #20479e] {
  col_a integer [pk, not null]
  col_b varchar(100) [not null, note: 'texto sin comillas simples']
  col_c decimal(12,2)
  fk_col integer [not null, ref: > otra_tabla.id]
  Note: 'nota a nivel de tabla'
}

Ref: tabla_a.fk_col > tabla_b.id
```

Reglas del subset:
- Nombres de tabla y columna: `[A-Za-z0-9_]+` (snake_case). Sin comillas, sin espacios, sin esquema. Ver §5.
- Settings de columna permitidos: `pk`, `not null`, `note: '...'`, `ref: <op> tabla.col`. Nada más (`unique`, `increment`, `default` **no** se emiten).
- `headercolor: #hex` es opcional y va en los settings de la tabla `[ ... ]`. Off por defecto (ver §7).
- `Note: '...'` a nivel de tabla: una sola línea, comillas simples, **sin apóstrofes dentro**.
- Tipos: se conservan tal cual del SQL (`integer`, `varchar(100)`, `decimal(12,2)`, `uuid`, `timestamp`, `boolean`, `text`, …). El plugin solo los muestra como texto; pueden llevar paréntesis, coma y espacios.
- Relaciones: inline `[ref: <op> tabla.col]` **o** línea suelta `Ref: a.col <op> b.col`. Usar líneas `Ref:` para FKs de constraint a nivel de tabla; inline para `REFERENCES` en la propia columna. No mezclar duplicando la misma relación.
- `op` ∈ `>` `<` `<>` `-` (ver §4).
- **Nunca** emitir: `indexes { }`, `enum`, `TableGroup`, refs multi-columna, `default`, `unique`. El plugin los ignora o no los parsea.

---

## 3. Mapeo SQL → DBML

| SQL (ANSI)                                   | DBML (subset)                                  |
| -------------------------------------------- | ---------------------------------------------- |
| `CREATE TABLE t (...)`                       | `Table t { ... }`                              |
| `col TYPE`                                   | `col type`                                     |
| `NOT NULL`                                   | `[not null]`                                   |
| `PRIMARY KEY` (inline, 1 col)                | `[pk]`                                          |
| `PRIMARY KEY (col)` (constraint, 1 col)      | marca esa columna `[pk]`                       |
| `col TYPE REFERENCES p(c)` (inline)          | `col type [ref: > p.c]` + preservar `not null` |
| `FOREIGN KEY (col) REFERENCES p(c)`          | línea `Ref: t.col > p.c`                       |
| `DEFAULT ...`                                | omitido (documentar en `Note` si es relevante) |
| `UNIQUE`, `CHECK`                            | omitido (documentar en `Note` si es relevante) |
| `schema.tabla`                               | `tabla` (esquema removido, ver §5)             |
| comentario de columna / `COMMENT ON`         | `[note: '...']`                                 |

Detalle completo y casos raros: `references/mapping-ansi-dbml.md`.

---

## 4. Cardinalidad de relaciones

El plugin **deriva** la marca de cada extremo, no la lee explícita. Regla clave:
la columna FK va siempre en el lado izquierdo (`from`) del `Ref`.

- FK normal (muchos→uno): `Ref: hijo.fk_col > padre.pk`
  - Lado `hijo`: pata de gallo (muchos).
  - Lado `padre`: el plugin pone **barra** (obligatorio) si `fk_col` es `not null`, o **círculo** (opcional) si es nullable. → **Siempre preservar `not null`/nullable de la columna FK.**
- FK que además es UNIQUE o PK (uno→uno): usar `-` → `Ref: hijo.fk_col - padre.pk`.
- No invertir el sentido: no usar `<` salvo que la FK quede inevitablemente en el lado derecho. Por defecto, FK a la izquierda con `>`.
- `<>` (muchos a muchos) **no** se genera desde un `CREATE TABLE`; una tabla puente produce dos `Ref` `>` (uno por cada FK).

---

## 5. Identificadores

- Quitar el esquema: `ventas.pedido` → `pedido`. Si al quitar esquemas hay colisión de nombres entre tablas, conservar un prefijo (`ventas_pedido`) y avisarlo.
- Quitar comillas/corchetes/backticks: `"Mi Tabla"`, `[Mi Tabla]`, `` `mi tabla` `` → normalizar a snake_case: `mi_tabla`.
- Caracteres no válidos o espacios → reemplazar por `_`. Acentos → sin acento.
- Aplicar la misma normalización a los nombres usados en los `Ref` para que coincidan con la tabla/columna destino.

---

## 6. Degradaciones (solo-subset)

El plugin solo dibuja el subset. Cuando el SQL trae algo fuera de él, degradar así
y **documentar lo perdido en un `Note:` de la tabla** (una línea, sin apóstrofes):

| Construcción SQL          | Degradación en el subset                                                            |
| ------------------------- | ----------------------------------------------------------------------------------- |
| PK compuesta `(a, b)`     | marcar `[pk]` en **cada** columna miembro + `Note: 'PK compuesta: (a, b)'`           |
| FK multi-columna          | emitir **un** `Ref` con el **primer** par de columnas + `Note` con la FK completa    |
| `enum`/`CREATE TYPE`      | el tipo de la columna queda como el nombre del enum (texto); listar valores en `Note`; descartar el `CREATE TYPE` |
| `DEFAULT`                 | omitir; si aporta info, mencionarlo en `Note`                                        |
| `UNIQUE` / `CHECK`        | omitir; si aporta info, mencionarlo en `Note`                                        |

Objetivo: que el bloque **siempre renderice** en Obsidian, aunque se pierda detalle
no visual. El detalle perdido queda trazado en la `Note`.

---

## 7. Convenciones opcionales (off por defecto)

**No** inventar columnas ni inferir convenciones por defecto: transcribir solo lo
que el SQL o el usuario indiquen. Esto mantiene la skill útil para cualquiera.

Activar convenciones **solo si el usuario lo pide explícitamente** ("aplica mis
convenciones", "agrega auditoría", "ponle PK surrogate", "colorea por módulo"):

- **PK surrogate**: si una tabla no tiene PK, agregar `id <tipo> [pk]`.
- **Auditoría**: agregar `created_at`, `updated_at`, `created_by_id`, `updated_by_id`, `is_active`.
- **FK naming**: nombrar FKs como `<entidad>_id`.
- **headercolor por módulo/esquema**: asignar un color por prefijo/esquema de tabla con `[headercolor: #hex]` y mostrar la leyenda color↔módulo.

Si se activan, decirlo explícitamente en la respuesta para que el usuario sepa qué
se añadió.

---

## 8. Modo incremental: preservar el bloque

Cuando se agregan tablas a un bloque dbml existente (modo B):

- **No tocar** las líneas `// @pos ...` ni `// @view ...`: son posiciones y vista que el plugin gestiona. Mantenerlas tal cual.
- **No tocar** los `[headercolor: #hex]` ya puestos por el usuario.
- **No reordenar ni reescribir** las tablas/relaciones existentes.
- Agregar las nuevas `Table` y sus `Ref` **antes** del bloque de comentarios `// @pos`/`// @view` (si existe), o al final si no existe.
- Si el usuario quiere reemplazar todo, confirmarlo antes (perdería posiciones guardadas).

---

## 9. Formato de entrega

- Salida principal: un bloque ```` ```dbml ```` listo para pegar en una nota de Obsidian.
- Si el usuario pide archivo: generar `<nombre>.dbml` (mismo contenido sin las fences).
- Tras el bloque, una línea breve con lo que se interpretó/omitió (degradaciones aplicadas), sin relleno.
- No agregar `// @pos`/`// @view`: esos los escribe el plugin al organizar el diagrama.

---

## 10. Checklist antes de entregar

1. Todos los nombres de tabla/columna son `[A-Za-z0-9_]+` (sin esquema, comillas ni espacios).
2. Cada `Ref` apunta a una tabla y columna que **existen** en el bloque.
3. Las columnas FK conservan su `not null`/nullable original (afecta la marca del plugin).
4. No quedó ninguna construcción fuera del subset (`indexes`, `enum`, `default`, `unique`, refs multi-columna).
5. Las `Note:` no contienen apóstrofes (rompen el parser).
6. Cada degradación aplicada quedó documentada en una `Note`.
7. En modo incremental, los comentarios `// @pos`/`// @view` y los `headercolor` previos siguen intactos.
