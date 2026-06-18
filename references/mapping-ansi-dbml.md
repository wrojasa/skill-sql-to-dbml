# Mapeo detallado ANSI SQL → DBML (subset del plugin)

Referencia de apoyo para `SKILL.md`. Leer cuando el script tenga constraints a
nivel de tabla, FKs por `ALTER`, tipos especiales o casos límite.

## Contenido

1. [Parseo del script](#1-parseo-del-script)
2. [Columnas y tipos](#2-columnas-y-tipos)
3. [Primary keys](#3-primary-keys)
4. [Foreign keys y cardinalidad](#4-foreign-keys-y-cardinalidad)
5. [Constraints sin equivalente visual](#5-constraints-sin-equivalente-visual)
6. [Enums y tipos definidos](#6-enums-y-tipos-definidos)
7. [Esquemas e identificadores](#7-esquemas-e-identificadores)
8. [Notas y comentarios](#8-notas-y-comentarios)

---

## 1. Parseo del script

- Procesar el lote completo antes de emitir: las FKs pueden venir por `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY ... REFERENCES` separado de los `CREATE TABLE`.
- Ignorar `GO`, `;` sueltos, `SET ...`, `USE ...`, `BEGIN/END` y demás ruido de despliegue.
- Resolver primero todas las tablas y columnas; luego las relaciones (inline + constraint + ALTER) para validar que ambos extremos existen.
- Si una FK apunta a una tabla que no está en el lote, emitir la relación igual y avisar que el destino no está definido en el bloque.

## 2. Columnas y tipos

- El tipo se copia **literal** del SQL, en minúsculas: `INTEGER`→`integer`, `VARCHAR(150)`→`varchar(150)`, `DECIMAL(12,2)`→`decimal(12,2)`, `TIMESTAMP WITH TIME ZONE`→`timestamp` (colapsar modificadores largos a la raíz si traen espacios problemáticos; el plugin solo lo muestra como texto, pero evitar saltos raros).
- `NOT NULL` → `not null`.
- `NULL` explícito → no se emite nada (nullable es el defecto en DBML).
- Identidad/autoincremento (`IDENTITY`, `AUTO_INCREMENT`, `SERIAL`, `GENERATED ... AS IDENTITY`): el plugin no tiene marca de auto-incremento dentro del subset; convertir `SERIAL`/`BIGSERIAL` a `integer`/`bigint` y omitir el auto-incremento (no usar `increment`, que está fuera del subset).
- `DEFAULT` → omitir (ver §5).

## 3. Primary keys

- Inline 1 columna: `id INTEGER PRIMARY KEY` → `id integer [pk]`.
- Constraint 1 columna: `PRIMARY KEY (id)` o `CONSTRAINT pk_x PRIMARY KEY (id)` → marcar `id` con `[pk]`.
- **Compuesta** `PRIMARY KEY (a, b)`: el subset no representa PK compuesta. Marcar `[pk]` en **cada** columna miembro (el plugin dibuja el ícono 🔑 en ambas) y agregar a la tabla `Note: 'PK compuesta: (a, b)'`. Es una aproximación visual; el detalle queda en la nota.

## 4. Foreign keys y cardinalidad

Regla base: **la columna FK va en el lado izquierdo (`from`) del `Ref`**, y la cardinalidad la deriva el plugin.

- Inline `dept_id INTEGER NOT NULL REFERENCES dept(id)`:
  - `dept_id integer [not null, ref: > dept.id]`
- Constraint `FOREIGN KEY (dept_id) REFERENCES dept(id)`:
  - línea `Ref: empleado.dept_id > dept.id`
- `ALTER TABLE empleado ADD CONSTRAINT fk ... FOREIGN KEY (dept_id) REFERENCES dept(id)`:
  - igual que constraint: `Ref: empleado.dept_id > dept.id`

Marcas que dibuja el plugin (no se escriben, se derivan):
- Lado `from` (FK): pata de gallo = "muchos".
- Lado `to` (PK referenciada):
  - **barra** (obligatorio) si la columna FK es `not null`.
  - **círculo** (opcional) si la columna FK es nullable.
- → **Preservar siempre** el `not null`/nullable de la columna FK. Es lo único que controla esa marca.

Uno a uno: si la columna FK es también PK o tiene `UNIQUE`, la relación es 1:1 → usar `-`:
- `person_id INTEGER PRIMARY KEY REFERENCES person(id)` → `Ref: profile.person_id - person.id`

FK multi-columna `FOREIGN KEY (a, b) REFERENCES p(x, y)`:
- El subset no soporta refs multi-columna. Emitir **un solo** `Ref` con el primer par: `Ref: t.a > p.x`, y documentar la FK completa en `Note: 'FK compuesta: (a, b) -> p(x, y)'`.

Tabla puente (N:M): no se infiere `<>`. Una tabla puente con dos FKs produce **dos** `Ref` `>`, uno hacia cada tabla. El rombo N:M no existe en el subset; queda como dos relaciones muchos→uno, que es lo correcto a nivel físico.

## 5. Constraints sin equivalente visual

- `DEFAULT <expr>`: omitir. Si el default codifica una regla importante, mencionarlo en `Note` (sin apóstrofes).
- `UNIQUE (col)` / `CONSTRAINT ... UNIQUE`: omitir del dibujo. Si es relevante (define un 1:1 junto con una FK, o una clave natural), documentar en `Note: 'UNIQUE: (col)'`. Recordar que un UNIQUE sobre una FK convierte la relación en 1:1 (`-`).
- `CHECK (...)`: omitir; opcional documentar en `Note`.
- `indexes`: nunca emitir el bloque `indexes { }` (el plugin lo ignora). Si un índice único define una relación 1:1, aplicarlo a la cardinalidad como en UNIQUE.

## 6. Enums y tipos definidos

- `CREATE TYPE x AS ENUM ('a','b','c')` (o equivalente): descartar la definición. Las columnas de tipo `x` conservan `x` como tipo (texto). En la tabla que use el enum, agregar `Note: 'enum x: a, b, c'`.
- Dominios/`CREATE DOMAIN`: usar el tipo base; documentar en `Note` si aporta.

## 7. Esquemas e identificadores

- `esquema.tabla` → `tabla`. Aplicar también en los `Ref` (destino sin esquema).
- Colisión tras quitar esquema (dos tablas con igual nombre en esquemas distintos): mantener un prefijo `esquema_tabla` en ambas y en sus refs; avisarlo.
- Comillas/corchetes/backticks: removerlos. Si el nombre tiene espacios o caracteres no `[A-Za-z0-9_]`, convertir a snake_case (espacios→`_`, quitar acentos, eliminar símbolos).
- Mantener un mapa nombre-original→nombre-DBML para reescribir correctamente las referencias.

## 8. Notas y comentarios

- Comentario de columna inline (`-- ...` al final, `COMMENT ON COLUMN`, `COMMENT '...'` de MySQL): pasar a `[note: '...']`.
- `Note:` de tabla: una sola línea, comillas simples, **sin apóstrofes internos** (rompen el parser del plugin). Si el texto trae apóstrofe, sustituirlo o quitarlo.
- Concatenar en una sola `Note` de tabla todas las degradaciones aplicadas (PK compuesta, UNIQUE, enum, FK compuesta, defaults relevantes) separadas por `. `.
