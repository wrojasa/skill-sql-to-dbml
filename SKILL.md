---
name: sql-to-dbml
description: >
  Convierte scripts SQL CREATE TABLE (ANSI, SQL Server, PostgreSQL o MySQL) o
  tablas que se van definiendo en código DBML que renderiza "DBML ER Diagrams"
  (plugin de Obsidian y extensión de VS Code, mismo parser) y dbdiagram.io.
  Usar SIEMPRE que el usuario pida generar o convertir DBML, comparta un script
  de creación de tablas y quiera verlo como diagrama, o diga "pásame el dbml
  de", "convierte este CREATE TABLE a dbml", "genera el dbml de estas tablas",
  "dbml para el plugin", "dbml para vscode", "crea el archivo .dbml", "arma el
  ERD en dbml", "el diagrama de estas tablas", "agrega esta tabla al dbml",
  "actualiza el dbml con", "agrupa las tablas por áreas". También en inglés:
  "convert this SQL to DBML", "generate the DBML or ERD for these tables", "add
  this table to the dbml". Activar aunque no se diga literalmente "DBML",
  también para mantener al día un bloque o archivo dbml existente. No usar para
  convertir DBML a SQL ni para diseñar un modelo de datos desde cero.
---

# SQL → DBML para DBML ER Diagrams (Obsidian y VS Code)

Genera DBML a partir de SQL `CREATE TABLE` o de tablas descritas en la
conversación. La salida se limita al subconjunto de DBML que dibuja "DBML ER
Diagrams" y que dbdiagram.io también acepta. "DBML ER Diagrams" existe en dos
formas con el mismo parser y las mismas anotaciones de layout: el plugin de
Obsidian (bloques ```` ```dbml ```` en notas) y la extensión de VS Code
(archivos `.dbml` y bloques ```` ```dbml ```` en Markdown). Un mismo bloque
se dibuja igual en ambas y puede moverse entre ellas. Lo que queda fuera del
subconjunto se degrada (§6). Nunca se emite sintaxis que alguna de las tres
herramientas no entienda.

**Parser verificado en el plugin v0.2.0; sin cambios en el plugin v0.3.0 ni
en la extensión de VS Code 0.1.0**, que usa el mismo código. Las reglas
también producen bloques correctos en versiones anteriores; si el usuario
tiene una, ver la última sección de `references/plugin-subset.md`. Si el
parser cambia, actualizar primero ese archivo.

## Archivos de apoyo

- `references/mapping-ansi-dbml.md`: reglas finas por dialecto. Leerlo siempre
  que el script traiga algo más que `CREATE TABLE` simples: `ALTER TABLE`,
  scripts de SSMS, MySQL o PostgreSQL, tipos raros, comentarios, enums,
  columnas computadas, herencia o particiones.
- `references/plugin-subset.md`: qué dibujan el plugin y la extensión, qué
  ignoran, qué pierden en silencio, qué estado guardan dentro del bloque y
  dónde debe estar el bloque en cada herramienta. Leerlo en modo incremental o
  cuando el usuario diga que algo no aparece en el diagrama.
- `examples/`: pares `.sql` → `.dbml`.

| Ejemplo | Qué muestra |
| --- | --- |
| `01-basico` | FK inline `not null`, PK con `not null` |
| `02-cardinalidad` | FK nullable, autorrelación, 1:1 con `-`, comentario `--` a `note` |
| `03-degradaciones` | esquema quitado, enum `CREATE TYPE`, PK compuesta, UNIQUE, DEFAULT, FK dentro de PK compuesta sigue con `>` |
| `04-incremental` | bloque con estado del plugin y de la extensión (`@pos`, `@edge`, `@group`, `@table`, `@view`, `@size`) y un área colapsada (`-antes.dbml`), tabla nueva (`.sql`), resultado (`-despues.dbml`) |
| `05-sqlserver` | script de SSMS: corchetes, `IDENTITY`, `COLLATE`, PK y FK por `ALTER`, case distinto, columna computada, `MS_Description`, `ON DELETE CASCADE` |
| `06-mysql` | backticks, `int(11) unsigned`, `ENUM` y `SET` inline, `COMMENT`, `UNIQUE KEY` sobre FK, `KEY`, `ENGINE` |
| `07-postgres` | estilo pg_dump: `public.`, arrays, identidad, columna generada, alias de tipos, `ALTER TABLE ONLY`, `COMMENT ON`, particiones |
| `08-areas` | el usuario pide agrupar por áreas: un `TableGroup` por esquema, con color, después de las tablas |

---

## 1. Modos de uso

**A. Desde script.** El usuario pega uno o varios `CREATE TABLE`, con o sin
`ALTER TABLE`. Resolver primero todas las tablas y columnas, después todas las
relaciones (inline, constraint y `ALTER`). Emitir el bloque completo.

**B. Incremental.** Ya existe un bloque dbml y el usuario agrega tablas o pide
cambiar una tabla concreta. Ver §8.

Si el lote mezcla dialectos o trae sintaxis ambigua, aplicar la regla más
cercana de `mapping-ansi-dbml.md` y decir al final qué se interpretó.

---

## 2. Sintaxis de salida

Emitir **únicamente** esta forma:

```dbml
Table cliente {
  id integer [pk, not null]
  nombre varchar(100) [not null, note: 'nombre comercial']
  saldo decimal(12,2)
  Note: 'nota de tabla, una sola línea, al final del cuerpo'
}

Table vendedor [headercolor: #20479e] {
  id integer [pk, not null]
  nombre varchar(100) [not null]
}

Table pedido {
  id integer [pk, not null]
  cliente_id integer [not null, ref: > cliente.id]
  vendedor_id integer
}

TableGroup ventas [color: #2e7d32] {
  cliente
  pedido
}

Ref: pedido.vendedor_id > vendedor.id
```

El bloque `TableGroup` solo aparece si el usuario pidió agrupar por áreas
(§7) o si ya existía en el bloque (§8).

Reglas de forma. Cada una evita una pérdida silenciosa en el plugin; el
detalle está en `plugin-subset.md`.

- `Table` con T mayúscula, nombre y `{` en la misma línea, una declaración por línea.
- Nombres de tabla y columna: `[A-Za-z0-9_]+`, solo ASCII, sin comillas ni esquema (§5).
- Una columna por línea: `nombre tipo [settings]`. El `]` se cierra en la misma línea y después no va nada: ni `,`, ni `;`, ni comentario.
- Tipo en minúsculas, sin `[` ni `]`, sin espacios fuera de paréntesis (§3).
- Settings permitidos, en este orden: `pk`, `not null`, `ref: > tabla.col` o `ref: - tabla.col`, `note: '...'`. Separados por `, `; `not null` con un solo espacio; `ref:` sin espacio antes de los dos puntos.
- Toda columna `pk` lleva también `not null`. Sin él no aparece el badge `NN`, y hasta v0.1.21 una PK que también es FK se dibujaba como opcional.
- Notas: comillas simples, una línea, sin apóstrofes y sin la secuencia `ref:`.
- `Note:` de tabla: una sola por tabla, como última línea del cuerpo.
- `Ref:` a nivel raíz, fuera de las llaves de cualquier tabla, con la forma exacta `Ref: hija.col > padre.col`.
- `headercolor`: solo `#rrggbb`. No se emite salvo que el usuario lo pida (§7).
- `TableGroup` (área): solo por pedido del usuario o si ya existe, con las reglas de §7.
- Orden: tablas padre antes que sus hijas, después los `TableGroup`, después las líneas `Ref:` (§9).

**Nunca emitir:** `indexes { }`, bloques `enum`, `Project`, `Note { }` en
bloque, notas con `'''`, comentarios `/* */`, refs multi-columna, settings
`unique`, `default` o `increment`, settings en `Ref` (`[delete: ...]`),
operadores `<` o `<>`, líneas `// @pos`, `// @edge`, `// @view`, `// @size`,
`// @group`, `// @table`. Algunos son inofensivos y otros borran tablas o
crean columnas fantasma; `plugin-subset.md` los separa.

---

## 3. Mapeo esencial

| SQL | DBML |
| --- | --- |
| `CREATE TABLE [esquema.]t (...)` | `Table t { ... }` |
| `col TYPE` | `col type`, con el tipo normalizado (abajo) |
| `NOT NULL` | `not null` |
| `PRIMARY KEY` inline, por constraint o por `ALTER TABLE` | `[pk, not null]` |
| `col TYPE REFERENCES p(c)` | `col type [ref: > p.c]`, preservando `not null` |
| `FOREIGN KEY (col) REFERENCES p(c)` en `CREATE` o `ALTER` | `Ref: t.col > p.c` |
| `DEFAULT`, `CHECK`, `UNIQUE`, `IDENTITY`, `ON DELETE` | omitidos; ver §6 |
| comentario de columna | `[note: '...']` |
| comentario de tabla | `Note: '...'` |

Normalización del tipo, en este orden. El detalle por dialecto está en
`mapping-ansi-dbml.md` §2.

1. Quitar corchetes, comillas y backticks: `[nvarchar](50)` → `nvarchar(50)`. Un tipo que empieza con `[` hace que el plugin borre la columna.
2. Minúsculas.
3. Quitar lo que no es tipo: `IDENTITY(...)`, `AUTO_INCREMENT`, `COLLATE x`, `CHARACTER SET x`, `UNSIGNED`, `ZEROFILL`, `ROWGUIDCOL`, `SPARSE`, `NOT FOR REPLICATION`, y el ancho de enteros de MySQL: `int(11)` → `int`.
4. Sin espacios fuera de paréntesis, porque dbdiagram.io los rechaza: `double precision` → `double`, `character varying(n)` → `varchar(n)`, `timestamp with time zone` → `timestamptz`, `timestamp without time zone` → `timestamp`. Sin alias conocido, entre comillas dobles: `"interval day to second"`.
5. `serial`, `bigserial`, `smallserial` → `integer`, `bigint`, `smallint`.
6. Arrays → `<base>_array`. Enum inline → `<col>_enum`. Columna computada sin tipo → `computed`. Ver §6.

---

## 4. Relaciones y cardinalidad

El plugin no lee la cardinalidad: la deriva del operador y de la nulabilidad
de la columna FK.

- **FK siempre a la izquierda, con `>`**: `Ref: hija.fk > padre.pk`. Lado hija: pata de gallo. Lado padre: **barra** si la FK es `not null`, **círculo** si es nullable. Preservar siempre la nulabilidad original de la FK.
- **1:1 con `-`** solo si el conjunto de columnas de la FK coincide exactamente con una PK, un UNIQUE o un índice único de la tabla hija. Una FK que es solo parte de una PK o UNIQUE compuesta sigue con `>`. Una tabla puente produce dos `>`.
- **Nunca `<`**: con `>` la FK queda siempre a la izquierda y el bloque se lee igual en todas partes. Hasta v0.1.21, `<` además ponía el ícono 🔗 en la columna equivocada. Si el usuario eligió "One to many" en el canvas, el bloque trae `<`: respetarlo, no reescribirlo. **Nunca `<>`**: N:M se modela con la tabla puente.
- **Inline o `Ref:`**: inline `[ref: ...]` cuando el SQL usa `REFERENCES` en la columna; línea `Ref:` para `FOREIGN KEY` de constraint o de `ALTER`. Cada relación se declara una sola vez: nunca inline y `Ref:` a la vez, ni dos operadores para el mismo par.
- **Ambos extremos deben existir** en el bloque, con el mismo case. Si la tabla o columna destino no está en el lote, no emitir la relación: documentarla en la `Note:` de la tabla como `FK pendiente: col -> tabla.col` y avisarlo. El plugin descarta en silencio una relación con un extremo inexistente y dbdiagram.io rechaza el bloque entero.
- FK multi-columna: ver §6.

---

## 5. Identificadores

- **Esquema fuera**: `dbo.cliente`, `[dbo].[cliente]`, `ventas.pedido` → `cliente`, `pedido`. Si dos tablas chocan al quitarlo, usar `esquema_tabla` en ambas y avisarlo. Si el usuario pide agrupar por áreas, el esquema original es el criterio por defecto (§7).
- **Delimitadores fuera**: quitar `"..."`, `[...]` y backticks. Espacios y símbolos → `_`. Acentos y ñ → ASCII: `año` → `anio`. El plugin borra en silencio tablas o columnas con caracteres fuera de `[A-Za-z0-9_]`.
- **Case canónico**: el nombre se escribe como aparece en su `CREATE TABLE` o en la definición de la columna. Las referencias (`REFERENCES`, `FOREIGN KEY`, `ALTER TABLE`) se emparejan sin distinguir mayúsculas y se reescriben con esa forma. SQL sin comillas no distingue case; el plugin y dbdiagram.io sí.
- Usar el mismo mapa nombre original → nombre DBML para tablas, columnas y refs.

---

## 6. Degradaciones

Lo que el diagrama no dibuja se omite y, si aporta información, se documenta
en la `Note:` de la tabla. **Ni el plugin (v0.3.0) ni la extensión de VS Code
(0.1.0) muestran las notas**, ni de tabla ni de columna. La nota queda en el
texto y se ve en dbdiagram.io. No decirle al usuario que la verá en el
diagrama de Obsidian o de VS Code.

| SQL | Salida |
| --- | --- |
| PK compuesta `(a, b)` | `[pk, not null]` en cada columna miembro. dbdiagram.io lo lee como PK compuesta; no hace falta Note. |
| FK multi-columna | un solo `Ref` con el primer par de columnas + Note `FK compuesta: (a, b) -> p(x, y)` |
| `CREATE TYPE x AS ENUM` | tipo `x`; Note `enum x: a, b, c`; descartar el `CREATE TYPE` |
| `ENUM('a','b')` inline | tipo `<col>_enum`; Note `enum <col>_enum: a, b` |
| `SET('a','b')` de MySQL | tipo `<col>_set`; Note `set <col>_set: a, b` |
| array `text[]` | tipo `text_array` |
| columna computada | tipo `computed` o el tipo declarado; `note:` con la expresión |
| `DEFAULT`, `CHECK` | omitir; Note solo si codifica una regla de negocio |
| `UNIQUE` | omitir; decide 1:1 (§4); Note `UNIQUE: (cols)` si es una clave natural |
| `IDENTITY`, `AUTO_INCREMENT`, `SERIAL` | omitir, sin Note |
| `ON DELETE` / `ON UPDATE` | omitir `NO ACTION` y `RESTRICT`; Note `col: ON DELETE CASCADE` para `CASCADE`, `SET NULL` o `SET DEFAULT` |
| índices no únicos | omitir, sin Note |
| particiones, `INHERITS` | ver `mapping-ansi-dbml.md` §10 |

Todas las degradaciones de una tabla van en su única `Note:`, separadas por
`. `. El comentario propio de la tabla, si existe, va primero.

---

## 7. Convenciones opcionales (apagadas por defecto)

No inventar columnas ni convenciones: transcribir solo lo que el SQL o el
usuario indiquen. Activar únicamente si el usuario lo pide:

| El usuario dice | Se aplica |
| --- | --- |
| "aplica mis convenciones" | PK surrogate + auditoría + nombres de FK |
| "ponle PK surrogate" | a cada tabla sin PK, primera columna `id integer [pk, not null]`, o el tipo de PK más usado en el lote |
| "agrega auditoría" | al final de cada tabla: `created_at timestamp [not null]`, `updated_at timestamp`, `created_by_id integer`, `updated_by_id integer`, `is_active boolean [not null]`. Sin `ref`, salvo que el usuario diga cuál es la tabla de usuarios. |
| "nombra las FK" | renombrar cada FK a `<tabla_padre>_id` y reescribir sus refs |
| "colorea por módulo" | `[headercolor: #rrggbb]` por esquema o prefijo, y una leyenda color ↔ módulo en la respuesta. Si también pidió áreas, usar el color de cada área. |
| "agrupa por áreas", "por esquema", "por módulo" | un `TableGroup` por grupo, con las reglas de abajo |

Paleta sugerida para módulos y áreas: `#20479e`, `#2e7d32`, `#c62828`,
`#6a1b9a`, `#ef6c00`, `#00838f`. Decir siempre en la respuesta qué se agregó o
renombró.

Reglas de las áreas (`TableGroup`), verificadas contra el plugin y contra el
parser de dbdiagram.io:

- **Criterio**: el que indique el usuario. Si no indica ninguno, el esquema original cuando el script trae más de uno; si no, el prefijo común del nombre (`ven_`, `inv_`). Si no hay un criterio claro, proponer la agrupación en la respuesta y pedir confirmación antes de emitirla.
- **Forma**: `TableGroup nombre [color: #rrggbb] {`, una tabla por línea, `}`. Nombre con `[A-Za-z0-9_]+`, único en el bloque. Un color de la paleta por área.
- **Miembros**: solo tablas que existen en el bloque, y cada tabla en una sola área. dbdiagram.io rechaza el bloque entero si un miembro no existe o se repite. Las tablas que no encajan en ningún grupo quedan sueltas.
- **Ubicación**: los bloques `TableGroup` van después de todas las tablas y antes de las líneas `Ref:`. En v0.1.22 y anteriores, una línea de miembro escrita antes de su tabla confundía el renombrado desde el canvas.
- **Versiones**: el plugin dibuja áreas desde v0.2.0 y la extensión de VS Code desde su 0.1.0. Versiones anteriores del plugin las ignoran sin dañar el diagrama.

---

## 8. Modo incremental

El bloque existente es la fuente de verdad: el usuario pudo cambiarlo desde el
canvas, renombrando, coloreando, cambiando cardinalidades, creando tablas y
áreas, moviendo tablas entre áreas o colapsando áreas y tablas. Leerlo
completo antes de editar. En VS Code el bloque puede ser un archivo `.dbml`
entero, sin cercas: las mismas reglas aplican al archivo completo.

- **No tocar el estado del diagrama**: ninguna línea `// @pos`, `// @edge`, `// @view`, `// @size`, `// @group`, `// @table` ni `// height:`, y ningún `headercolor` existente, tenga el formato que tenga. Da igual qué herramienta las escribió: cada una conserva las de la otra.
- **Áreas existentes**: conservar cada `TableGroup` tal cual, aunque el usuario no haya pedido áreas en esta conversación. Una tabla nueva entra a un área solo si el usuario lo pide: agregar su nombre como línea de miembro en ese `TableGroup`. Si el usuario pide renombrar o borrar una tabla, actualizar también su línea de miembro. Un área nueva va después de las tablas.
- **No reordenar ni reescribir** tablas o relaciones existentes. Si el usuario pide cambiar una tabla, tocar solo las líneas pedidas y fusionar los datos nuevos en su `Note:` existente.
- **Dónde va una tabla nueva**: antes de la primera tabla existente que la referencia; si ninguna la referencia, después de la última tabla. Así los padres quedan antes que las hijas, el bloque se lee mejor y se evita un bug de v0.1.21 y anteriores: renombrar o borrar una tabla desde el canvas atacaba la primera línea que empezara con su nombre, así que con la hija antes, renombrar `vendedor` modificaba la columna `vendedor_id`.
- **Relaciones nuevas**: inline en la tabla nueva, o una línea `Ref:` nueva después de las existentes, nunca dentro de un cuerpo de tabla.
- **FK pendientes**: si la tabla nueva resuelve un `FK pendiente` de una Note, agregar la relación y quitar ese ítem de la Note. Si era el único, quitar la línea `Note:`.
- El plugin y la extensión reescriben las líneas `// @` al final del bloque cada vez que guardan el layout, así que su posición relativa da igual. Lo único prohibido es borrarlas o cambiarlas.
- Las tablas nuevas se ubican solas y pueden quedar encima de tablas que el usuario fijó. Avisarlo para que las mueva.
- **Regenerar todo** solo con confirmación. Si se regenera, conservar al final las líneas `// @` existentes: las posiciones de tablas que mantienen su nombre se respetan.

---

## 9. Formato de entrega

- Salida principal: un bloque ```` ```dbml ```` listo para pegar. El mismo texto sirve en las tres herramientas; cambia solo dónde va:
  - **Obsidian**: a nivel raíz de una nota `.md`. Dentro de un callout `> [!note]` o de un ítem de lista el plugin dibuja, pero no guarda posiciones ni permite editar. Un archivo `.dbml` suelto no se dibuja.
  - **VS Code**: un archivo `<nombre>.dbml` con el contenido sin cercas (se abre con el icono de diagrama de la barra de título, el comando "DBML ERD: Open ER Diagram to the Side" o *Open With… → DBML ER Diagram*), o un bloque ```` ```dbml ```` en un `.md` (la cerca abre la línea, sangría permitida, no dentro de `> `; con el cursor en el bloque, el mismo comando). Cada bloque tiene su propio panel.
  - **dbdiagram.io / `@dbml/cli`**: el archivo `.dbml` o el contenido del bloque.
- Si el usuario no dice en qué herramienta está, entregar el bloque: vale para todas, y el archivo `.dbml` es el mismo contenido sin cercas. Si lo pide como archivo, o trabaja en un proyecto de VS Code (Claude Code dentro de un repo), escribir `<nombre>.dbml` en UTF-8 sin BOM y decir cómo abrir el diagrama. Si está en Obsidian, bloque en la nota.
- Orden: tablas padre antes que hijas, en orden topológico; en ciclos, el orden del script. Después, los bloques `TableGroup`, si los hay. Al final, las líneas `Ref:`.
- Después del bloque, una línea breve con lo interpretado: degradaciones, FK pendientes, nombres cambiados, convenciones aplicadas, áreas creadas y su criterio.

---

## 10. Checklist antes de entregar

1. Nombres `[A-Za-z0-9_]+`, ASCII, sin esquema ni comillas, con el case canónico en tablas, columnas y refs.
2. `Table` con mayúscula, `{` en la misma línea, todas las llaves cerradas, una declaración por línea.
3. Una columna por línea, `]` cerrado en la misma línea y nada después.
4. Tipos en minúsculas, sin `[`, sin espacios fuera de paréntesis salvo entre comillas dobles.
5. Toda columna `pk` tiene `not null`; cada FK conserva su nulabilidad original.
6. Cada relación: FK a la izquierda, operador `>` o `-`, ambos extremos existen, declarada una sola vez, `Ref:` fuera de los cuerpos de tabla.
7. `-` solo donde la FK coincide exactamente con una PK o UNIQUE.
8. Notas con comillas simples, en una línea, sin apóstrofes ni `ref:`; una `Note:` por tabla, al final del cuerpo.
9. Nada de la lista "Nunca emitir" de §2.
10. Cada degradación con información útil quedó en una Note y la respuesta la resume.
11. Tablas padre antes que hijas.
12. Incremental: líneas `// @` (incluidas `// @group` y `// @table`) y `// height:` intactas, `headercolor` y `TableGroup` previos intactos, tablas existentes en su orden.
13. Áreas: solo si el usuario las pidió o ya existían; nombres únicos; cada tabla en una sola área; solo tablas que existen; bloques `TableGroup` después de las tablas y antes de los `Ref:`.
