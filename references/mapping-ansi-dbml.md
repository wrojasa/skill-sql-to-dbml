# Mapeo detallado SQL → DBML (subset del plugin)

Referencia de apoyo para `SKILL.md`. Cubre ANSI, SQL Server (scripts de SSMS),
PostgreSQL (pg_dump) y MySQL (`SHOW CREATE TABLE`, mysqldump). Las reglas de
forma de la salida y de cardinalidad están en `SKILL.md` §2 y §4; aquí no se
repiten.

## Contenido

1. Parseo del script
2. Tipos
3. Primary keys
4. Foreign keys
5. Constraints e índices sin dibujo
6. Enums, sets y dominios
7. Columnas computadas e identidad
8. Esquemas, identificadores y case
9. Comentarios y notas
10. Herencia y particiones (PostgreSQL)

---

## 1. Parseo del script

- Leer el lote completo antes de emitir. Resolver primero tablas y columnas, después relaciones.
- **Ruido que se ignora sin Note**:
  - Despliegue: `GO`, `USE`, `SET ...`, `BEGIN`/`END`, `;` sueltos, `SELECT pg_catalog.set_config(...)`, `OWNER TO`, `GRANT`, `REVOKE`.
  - Almacenamiento: `ON [PRIMARY]`, `TEXTIMAGE_ON [...]`, `WITH (PAD_INDEX = ..., ...)`, `TABLESPACE`, `ENGINE=...`, `AUTO_INCREMENT=n`, `DEFAULT CHARSET=...`, `COLLATE=...` de tabla, `ROW_FORMAT=...`.
  - Activación de constraints: `ALTER TABLE x CHECK CONSTRAINT y`, `WITH CHECK`, `WITH NOCHECK`. Solo activan una FK que ya está declarada.
  - Objetos que no son tablas: `CREATE SEQUENCE`, `ALTER SEQUENCE`, `CREATE INDEX` no único, `CREATE STATISTICS`, triggers, vistas, funciones, procedimientos.
- **`ALTER TABLE` que sí cuentan**: `ADD [CONSTRAINT x] PRIMARY KEY`, `ADD ... FOREIGN KEY`, `ADD ... UNIQUE`, `ADD ... DEFAULT ... FOR col`, `ADD ... CHECK`, `ADD [COLUMN] col tipo`, `ATTACH PARTITION`. `ALTER TABLE ONLY` de pg_dump equivale a `ALTER TABLE`.
- `CREATE UNIQUE INDEX ix ON t (cols)` cuenta como UNIQUE para decidir 1:1.
- Strings de SQL Server con prefijo `N'...'`: quitar la `N`.

## 2. Tipos

Aplicar en orden:

1. **Delimitadores**: quitar corchetes, comillas y backticks. `[int]` → `int`, `[nvarchar](50)` → `nvarchar(50)`, `[numeric](18, 0)` → `numeric(18,0)`. El parser del plugin trata el primer `[` de la línea como inicio de settings: un tipo entre corchetes borra la columna y, con ella, sus relaciones.
2. **Minúsculas**: `VARCHAR(150)` → `varchar(150)`.
3. **Modificadores que no son tipo**, se quitan: `IDENTITY(s,i)`, `AUTO_INCREMENT`, `GENERATED {ALWAYS | BY DEFAULT} AS IDENTITY`, `COLLATE x`, `CHARACTER SET x`, `CHARSET x`, `UNSIGNED`, `SIGNED`, `ZEROFILL`, `ROWGUIDCOL`, `SPARSE`, `FILESTREAM`, `NOT FOR REPLICATION`, `MASKED WITH (...)`, `ON UPDATE CURRENT_TIMESTAMP`. `NULL` no se emite; `NOT NULL` va a settings; `DEFAULT` sigue §5; `COMMENT '...'` sigue §9.
4. **Ancho de enteros de MySQL**: `int(11)`, `bigint(20)`, `smallint(6)`, `tinyint(4)`, `tinyint(1)` → sin paréntesis.
5. **Precisión**: sin espacios dentro de paréntesis, `decimal(18, 2)` → `decimal(18,2)`. Es cosmético.
6. **Sin espacios fuera de paréntesis**. dbdiagram.io rechaza `double precision` sin comillas. Alias:

| SQL | DBML |
| --- | --- |
| `double precision` | `double` |
| `character varying(n)`, `char varying(n)` | `varchar(n)` |
| `character(n)` | `char(n)` |
| `national character varying(n)`, `national char varying(n)` | `nvarchar(n)` |
| `national character(n)` | `nchar(n)` |
| `timestamp with time zone` | `timestamptz` |
| `timestamp without time zone` | `timestamp` |
| `time with time zone` | `timetz` |
| `time without time zone` | `time` |
| `bit varying(n)` | `varbit(n)` |

   Sin alias conocido, el tipo va entre comillas dobles: `"interval day to second"`. El plugin muestra las comillas como parte del tipo; dbdiagram.io lo acepta.
7. **Seriales**: `serial` → `integer`, `bigserial` → `bigint`, `smallserial` → `smallint`.
8. **Arrays**: `tipo[]`, `tipo[][]`, `tipo[3]`, `tipo ARRAY` → `<base>_array`, con la base sin parámetros: `varchar(50)[]` → `varchar_array`. Si se perdieron parámetros, Note `col: varchar(50)[]`. El plugin corta el tipo en el primer `[` y no deja rastro del array.
9. **Tipos con esquema**: `public.mi_tipo`, `dbo.MiTipo` → sin esquema.
10. **Dominios y tipos de usuario** (`CREATE DOMAIN`, `CREATE TYPE x FROM varchar(20)` de SQL Server): usar el tipo base. Note `col: dominio x` solo si aporta.
11. **Enum y SET inline**: §6. **Columnas computadas**: §7.

## 3. Primary keys

- Siempre `[pk, not null]`. El plugin no deduce `not null` de `pk`: sin él, una PK que también es FK se dibuja como opcional y la columna no muestra el badge `NN`.
- Formas equivalentes:
  - Inline: `id INTEGER PRIMARY KEY` → `id integer [pk, not null]`.
  - Constraint: `CONSTRAINT pk_x PRIMARY KEY (id)`.
  - SSMS: `CONSTRAINT [PK_x] PRIMARY KEY CLUSTERED ([id] ASC) WITH (...) ON [PRIMARY]`. Ignorar `CLUSTERED`, `NONCLUSTERED`, `ASC`, `DESC`, `WITH` y `ON`.
  - pg_dump: `ALTER TABLE ONLY public.x ADD CONSTRAINT x_pkey PRIMARY KEY (id);`.
- **Compuesta** `PRIMARY KEY (a, b)`: `[pk, not null]` en cada columna miembro. El plugin dibuja 🔑 en cada una y dbdiagram.io lo interpreta como PK compuesta. No hace falta Note.
- Nunca declarar la PK dentro de `indexes { }`: el plugin ignora ese bloque completo.

## 4. Foreign keys

- **Inline** `dept_id INTEGER NOT NULL REFERENCES dept(id)` → `dept_id integer [not null, ref: > dept.id]`.
- **Constraint o ALTER** `FOREIGN KEY (dept_id) REFERENCES dept(id)` → `Ref: empleado.dept_id > dept.id`.
- `REFERENCES p` sin columna apunta a la PK de `p`.
- **1:1**: el conjunto de columnas de la FK debe coincidir exactamente con el de una PK, un UNIQUE o un índice único de la tabla hija.
  - `person_id INTEGER PRIMARY KEY REFERENCES person(id)` → `person_id integer [pk, not null, ref: - person.id]`.
  - `UNIQUE KEY (usuario_id)` sobre la FK `usuario_id` → `Ref: perfil.usuario_id - usuario.id`.
  - FK `order_id` dentro de `PRIMARY KEY (order_id, line_no)` → sigue `>`.
  - FK compuesta `(a, b)` igual a la PK compuesta `(a, b)` → `-`.
- **Tabla puente** con dos FKs → dos `Ref` con `>`, uno hacia cada tabla.
- **Multi-columna**: el subset no tiene refs multi-columna. Emitir un `Ref` con el primer par y documentar en la Note de la tabla hija: `FK compuesta: (a, b) -> p(x, y)`.
- **Destino ausente**: si la tabla o la columna destino no está en el bloque, no emitir el `Ref`. Note `FK pendiente: col -> tabla.col` y avisarlo. Al agregar después esa tabla, crear el `Ref` y quitar el ítem de la Note.
- **`ON DELETE` / `ON UPDATE`**: omitir `NO ACTION` y `RESTRICT`. Para `CASCADE`, `SET NULL` o `SET DEFAULT`, Note `col: ON DELETE CASCADE`. No usar `[delete: ...]` en el `Ref`: el plugin lo tolera, pero queda fuera del subset.
- **Case**: emparejar tabla y columna destino sin distinguir mayúsculas y escribirlas con la forma canónica (§8).

## 5. Constraints e índices sin dibujo

- **DEFAULT**, en cualquiera de sus formas (inline, `CONSTRAINT DF_x DEFAULT (v) FOR col`, `DEFAULT CURRENT_TIMESTAMP`): omitir. Note solo si codifica una regla de negocio.
- **UNIQUE** (inline, constraint, `UNIQUE KEY` de MySQL, `CREATE UNIQUE INDEX`): omitir del dibujo. Sirve para decidir 1:1 (§4). Note `UNIQUE: (cols)` cuando es una clave natural, no cuando solo marca un 1:1 que ya se ve con `-`.
- **CHECK**: omitir. Note opcional `CHECK: expr`, sin apóstrofes.
- **Índices no únicos** (`KEY`, `INDEX`, `FULLTEXT KEY`, `SPATIAL KEY` dentro del `CREATE TABLE` de MySQL, o `CREATE INDEX`): omitir sin Note. Nunca dejarlos como líneas dentro del cuerpo: el plugin los dibuja como columnas fantasma.
- Nunca emitir `indexes { }`.

## 6. Enums, sets y dominios

- `CREATE TYPE x AS ENUM ('a','b','c')`: descartar la definición. Las columnas de tipo `x` conservan `x`. En cada tabla que lo usa, Note `enum x: a, b, c`.
- `ENUM('a','b')` inline de MySQL: tipo `<col>_enum` y Note `enum <col>_enum: a, b`. Si dos tablas tienen enums distintos con el mismo nombre de columna, usar `<tabla>_<col>_enum`.
- `SET('a','b')` de MySQL: tipo `<col>_set` y Note `set <col>_set: a, b`.
- No dejar `enum('a','b')` como tipo. El plugin y dbdiagram.io lo aceptan, pero la tabla se ensancha con todos los valores y mete apóstrofes en una línea de columna. Se usa `<col>_enum` por coherencia con `CREATE TYPE`. Si el usuario prefiere ver los valores en el diagrama, puede pedirlo: la Note no se muestra en el plugin.
- Nunca emitir un bloque `enum x { }`: el plugin lo ignora y queda fuera del subset. Hasta v0.1.21, un `enum {` sin nombre creaba una tabla fantasma.

## 7. Columnas computadas e identidad

- **SQL Server** `col AS (expr) [PERSISTED]`: tipo `computed`, `note: 'AS (expr) PERSISTED'`. Quitar corchetes de la expresión y cambiar sus apóstrofes por comillas dobles. Sin `not null`.
- **PostgreSQL, MySQL, estándar** `col tipo GENERATED ALWAYS AS (expr) STORED | VIRTUAL`: conservar el tipo; `note: 'GENERATED ALWAYS AS (expr) STORED'`.
- **Identidad y autoincremento** (`IDENTITY`, `AUTO_INCREMENT`, `SERIAL`, `GENERATED ... AS IDENTITY`): omitir sin Note. No usar el setting `increment`.

## 8. Esquemas, identificadores y case

- **Esquema**: `esquema.tabla` → `tabla`, también en refs y tipos. Si dos tablas chocan, `esquema_tabla` en ambas y avisarlo. Si el usuario pide agrupar por áreas, recordar el esquema original de cada tabla: es el criterio por defecto para formar las áreas (`SKILL.md` §7).
- **Delimitadores**: quitar `"..."`, `[...]` y backticks.
- **Caracteres**: espacios y símbolos → `_`; acentos y ñ → ASCII; espacios invisibles (NBSP, BOM) → eliminar. El plugin borra en silencio una tabla o columna con caracteres fuera de `[A-Za-z0-9_]`. Hasta v0.1.21, también una tabla con un NBSP o un BOM antes de su declaración.
- **Case canónico**: la forma del `CREATE TABLE` para la tabla y la de la definición para la columna. Toda referencia se empareja sin distinguir mayúsculas y se reescribe con esa forma. Ejemplo: `CREATE TABLE [dbo].[Cliente] ([IdCliente] ...)` + `REFERENCES dbo.cliente(idcliente)` → `ref: > Cliente.IdCliente`.
- Mantener un mapa nombre original → nombre DBML y aplicarlo en tablas, columnas, refs y notas.
- Nombres reservados en SQL (`order`, `user`, `group`), y columnas llamadas `indexes` o `pk`, no dan problema ni en el plugin desde v0.1.22 ni en dbdiagram.io.

## 9. Comentarios y notas

| Origen | Destino |
| --- | --- |
| `-- texto` al final de la línea de una columna | `note:` de esa columna |
| `COMMENT 'texto'` de columna (MySQL) | `note:` |
| `COMMENT ON COLUMN t.c IS 'texto'` | `note:` |
| `sp_addextendedproperty @name=N'MS_Description'` con `@level2type=N'COLUMN'` | `note:` de esa columna |
| `COMMENT ON TABLE t IS 'texto'` | `Note:` de tabla |
| `COMMENT='texto'` como opción de tabla (MySQL) | `Note:` de tabla |
| `sp_addextendedproperty @name=N'MS_Description'` solo hasta `@level1type=N'TABLE'` | `Note:` de tabla |
| `--` en una línea propia, `/* ... */` | se ignora |

Reglas del texto:

- Comillas simples, una sola línea. Los saltos de línea se vuelven espacio.
- Sin apóstrofes. En prosa, reformular. En expresiones SQL, cambiarlos por comillas dobles. dbdiagram.io rechaza un apóstrofe sin escapar dentro de una cadena, y hasta v0.1.21 el plugin truncaba la nota y leía el resto como settings.
- Delimitar siempre con comillas simples. Desde v0.1.22 el plugin y dbdiagram.io aceptan `note: "..."`, pero hasta v0.1.21 el plugin leía ese texto como settings.
- Sin la secuencia `ref:` dentro de una nota de columna: hasta v0.1.21 creaba una relación fantasma.
- La `Note:` de tabla es única y va al final del cuerpo. Orden: comentario de la tabla, luego degradaciones, separados por `. `.
- El plugin (v0.2.0) no muestra notas. Son útiles en dbdiagram.io y al leer el bloque.

## 10. Herencia y particiones (PostgreSQL)

- `PARTITION BY RANGE (col)` en la tabla padre: Note `Particionada por RANGE (col)`.
- `CREATE TABLE hija PARTITION OF padre ...` o `ALTER TABLE padre ATTACH PARTITION hija ...`: no emitir la partición. Listarla en la Note de la padre: `Particiones: hija_2024, hija_2025`. Sus constraints y FKs son las de la padre.
- `CREATE TABLE hija (...) INHERITS (padre)`: emitir la hija con las columnas heredadas primero, con su tipo y nulabilidad pero sin `pk`, porque PostgreSQL no hereda PK, UNIQUE ni FK. Después sus columnas propias. Note `INHERITS padre`.
