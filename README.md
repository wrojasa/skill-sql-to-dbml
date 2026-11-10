# skill-sql-to-dbml

Skill de Claude que convierte scripts **SQL `CREATE TABLE`** —ANSI, SQL Server,
PostgreSQL o MySQL— o tablas que vas definiendo en código **DBML** compatible con
el plugin de Obsidian [**DBML ER Diagrams**](https://github.com/wrojasa/obsidian-dbml-erd).

El DBML generado se ciñe al subconjunto que ese plugin renderiza y que
[dbdiagram.io](https://dbdiagram.io) también acepta. Lo que el plugin no dibuja
(PK compuesta, FK multi-columna, enums, defaults, unique) se degrada a una forma
equivalente del subconjunto y se documenta en una nota, de modo que el bloque
**siempre renderiza**.

**Compatibilidad:** verificada contra DBML ER Diagrams **v0.2.0**. Los bloques
que genera también funcionan en versiones anteriores del plugin.

## Qué hace

- Lee uno o varios `CREATE TABLE`, con sus `ALTER TABLE`, y emite un bloque ```` ```dbml ````.
- Normaliza scripts reales: corchetes y `IDENTITY` de SSMS, backticks y `int(11) unsigned` de MySQL, esquemas, arrays y alias de tipos de PostgreSQL, diferencias de mayúsculas entre tablas y referencias.
- Detecta PK, NOT NULL y FKs. Toda PK sale con `not null`, y cada FK conserva su nulabilidad, que es lo que decide la marca obligatorio u opcional en el diagrama.
- Orienta las relaciones como el plugin las espera (`hija.fk > padre.pk`) y usa `-` solo para un 1:1 real.
- Modo incremental: agrega tablas a un bloque existente **sin tocar** el estado que guarda el plugin (`// @pos`, `// @edge`, `// @view`, `// @size`, `// @group`), los colores que ya pusiste ni tus áreas.
- Áreas de trabajo: si se lo pides ("agrupa por áreas", "por esquema" o "por módulo"), agrupa las tablas en bloques `TableGroup` con color, que el plugin dibuja como áreas desde v0.2.0.
- Convenciones (PK surrogate, columnas de auditoría, nombres de FK, color por módulo): **opcionales**, solo si las pides.

El plugin (v0.2.0) no muestra las notas en el diagrama. Las degradaciones quedan
en el texto del bloque y se ven en dbdiagram.io.

## Instalación

### En Claude Code

```bash
git clone https://github.com/wrojasa/skill-sql-to-dbml.git ~/.claude/skills/sql-to-dbml
```

Debe quedar `~/.claude/skills/sql-to-dbml/SKILL.md`, sin un nivel de carpeta de
más. Inicia una sesión nueva y confírmalo con `/skills`. Para que la skill viaje
con un repo concreto en vez de ser global, ponla en `.claude/skills/sql-to-dbml/`
dentro del proyecto. Para actualizarla: `git -C ~/.claude/skills/sql-to-dbml pull`.

### En Claude.ai, la app de escritorio o Cowork

Claude.ai pide un **ZIP** cuya carpeta raíz se llame igual que la skill,
`sql-to-dbml`, con `SKILL.md`, `references/` y `examples/` dentro. El botón
**Code → Download ZIP** de GitHub no sirve tal cual: su carpeta raíz se llama
`skill-sql-to-dbml-main`. Genera el ZIP desde un clon:

```bash
git archive --format=zip --prefix=sql-to-dbml/ -o sql-to-dbml.zip HEAD
```

Luego ve a **Customize > Skills**, pulsa **"+"** y **"+ Create skill"**, y sube
el ZIP. Si ya la tenías, reemplázala con el ZIP nuevo: una versión subida solo
con `SKILL.md` deja sin efecto las referencias a `references/` y `examples/`.

Las skills que subes son privadas a tu cuenta; en planes Team/Enterprise un
propietario puede habilitar compartirlas con la organización.

### Estructura

```
sql-to-dbml/
├── SKILL.md
├── references/
│   ├── mapping-ansi-dbml.md   reglas finas por dialecto
│   └── plugin-subset.md       qué dibuja, ignora o pierde el plugin
└── examples/
    ├── 01-basico               FK inline, PK con not null
    ├── 02-cardinalidad         FK nullable, autorrelación, 1:1
    ├── 03-degradaciones        esquema, enum, PK compuesta, UNIQUE, DEFAULT
    ├── 04-incremental          bloque con estado del plugin y un área + tabla nueva
    ├── 05-sqlserver            script de SSMS
    ├── 06-mysql                SHOW CREATE TABLE de MySQL
    ├── 07-postgres             pg_dump de PostgreSQL
    └── 08-areas                agrupar por áreas (un TableGroup por esquema)
```

Esta skill **no usa tags ni releases**: siempre se toma el estado actual de `main`.

## Uso

Ejemplos de cómo pedirlo:

- "Pásame el dbml de este script" + pegar los `CREATE TABLE`.
- "Convierte estas tablas a dbml para el plugin."
- "Agrega esta tabla al dbml" + pegar el bloque actual (modo incremental).
- "Genera el dbml y aplica mis convenciones" (PK surrogate + auditoría + nombres de FK).
- "Pásame el dbml y agrupa por áreas" (un área por esquema, o por el criterio que indiques).
- "Convert this SQL to DBML."

Entrada (`examples/01-basico.sql`):

```sql
CREATE TABLE department (
  id   INTEGER PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);

CREATE TABLE employee (
  id            INTEGER PRIMARY KEY,
  full_name     VARCHAR(150) NOT NULL,
  email         VARCHAR(150),
  department_id INTEGER NOT NULL REFERENCES department(id)
);
```

Salida (`examples/01-basico.dbml`):

```dbml
Table department {
  id integer [pk, not null]
  name varchar(100) [not null]
}

Table employee {
  id integer [pk, not null]
  full_name varchar(150) [not null]
  email varchar(150)
  department_id integer [not null, ref: > department.id]
}
```

Pega el bloque en una nota a nivel raíz, no dentro de un callout ni de una
lista: ahí el plugin dibuja, pero no guarda posiciones ni permite editar.

## Alcance

- Entrada: ANSI y los dialectos de SQL Server, PostgreSQL y MySQL. Se ignora el ruido de despliegue (`GO`, `USE`, `SET`, `ON [PRIMARY]`, `ENGINE=`).
- Salida: **solo el subset** que renderiza el plugin DBML ER Diagrams y acepta dbdiagram.io.
- No inventa columnas ni convenciones por defecto; transcribe lo que indiques.
- No convierte DBML a SQL ni diseña modelos de datos desde cero.

## Mantenimiento

`references/plugin-subset.md` describe el parser del plugin en la versión
indicada arriba. Cuando el plugin cambie su parser o el estado que guarda en el
bloque, actualiza ese archivo y la versión en `SKILL.md` y en este README.

## Licencia

MIT — ver [LICENSE](LICENSE).
