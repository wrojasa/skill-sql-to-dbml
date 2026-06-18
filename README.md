# skill-sql-to-dbml

Skill de Claude que convierte scripts **SQL `CREATE TABLE` (ANSI genérico)** —o
tablas que vas definiendo— en código **DBML** compatible con el plugin de Obsidian
[**DBML ER Diagrams**](https://github.com/wrojasa/obsidian-dbml-erd).

El DBML generado se ciñe al subconjunto que ese plugin renderiza, así que el
diagrama se ve correctamente en Obsidian (y también en
[dbdiagram.io](https://dbdiagram.io)). Lo que el plugin no dibuja (PK compuesta,
FK multi-columna, enums, defaults, unique) se degrada a una forma equivalente del
subconjunto y se documenta en una nota, de modo que el bloque **siempre renderiza**.

## Qué hace

- Lee uno o varios `CREATE TABLE` (y `ALTER TABLE ... ADD FOREIGN KEY`) y emite un bloque ```` ```dbml ````.
- Detecta PK, NOT NULL y FKs; orienta las relaciones como el plugin las espera (`hijo.fk > padre.pk`) y preserva el `not null`/nullable de la FK (controla la marca obligatorio/opcional).
- Modo incremental: agrega tablas nuevas a un bloque existente **sin tocar** las posiciones (`// @pos`), la vista (`// @view`) ni los colores que ya pusiste.
- Convenciones (PK surrogate, columnas de auditoría, FK `_id`, color por módulo): **opcionales**, solo si las pides.

## Instalación

La forma de instalar depende de dónde uses Claude.

### Descargar desde GitHub

- **ZIP (simple):** botón verde **Code → Download ZIP**. No lo descomprimas si vas a subirlo a Claude.ai.
- **git:** `git clone https://github.com/wrojasa/skill-sql-to-dbml.git`

### En Claude.ai / app de escritorio / Cowork

1. Usa el ZIP de GitHub tal cual (contiene la carpeta con `SKILL.md` dentro). Claude.ai pide el **ZIP**, no la carpeta descomprimida ni un enlace.
2. Ve a **Customize > Skills**, pulsa **"+"** y luego **"+ Create skill"**, y sube el ZIP.
3. Claude lee el `SKILL.md`, muestra nombre y descripción, y la skill queda en tu lista con un toggle para activarla/desactivarla.

Las skills que subes son privadas a tu cuenta; en planes Team/Enterprise un propietario puede habilitar compartirlas con la organización.

### En Claude Code / Claude Desktop

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/wrojasa/skill-sql-to-dbml.git sql-to-dbml
```

Debe quedar `~/.claude/skills/skill-sql-to-dbml/SKILL.md` directo (sin anidar un nivel de más). Inicia una sesión nueva y confírmalo con `/skills`. Para que la skill viaje con un repo concreto en vez de ser global, ponla en `.claude/skills/` dentro del proyecto.

### Estructura

```
skill-sql-to-dbml/
├── SKILL.md
├── references/
│   ├── mapping-ansi-dbml.md
│   └── plugin-subset.md
└── examples/
    ├── 01-basico.sql / .dbml
    ├── 02-cardinalidad.sql / .dbml
    └── 03-degradaciones.sql / .dbml
```

El error más común es el **doble anidamiento**: el `SKILL.md` debe quedar directo dentro de la carpeta de la skill. Esta skill **no usa tags ni releases**: siempre se toma el estado actual de `main`.

## Uso

Ejemplos de cómo pedirlo:

- "Pásame el dbml de este script" + pegar los `CREATE TABLE`.
- "Convierte estas tablas a dbml para el plugin."
- "Agrega esta tabla al dbml" (modo incremental).
- "Genera el dbml y aplica mis convenciones" (activa PK surrogate + auditoría + FK `_id`).

Entrada:

```sql
CREATE TABLE department (
  id   INTEGER PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);
CREATE TABLE employee (
  id            INTEGER PRIMARY KEY,
  full_name     VARCHAR(150) NOT NULL,
  department_id INTEGER NOT NULL REFERENCES department(id)
);
```

Salida:

```dbml
Table department {
  id integer [pk]
  name varchar(100) [not null]
}

Table employee {
  id integer [pk]
  full_name varchar(150) [not null]
  department_id integer [not null, ref: > department.id]
}
```

Más casos (cardinalidad 1:1, PK compuesta, enums, defaults) en `examples/`.

## Alcance

- Dialecto de entrada: **ANSI / SQL genérico**. Se ignora el ruido de despliegue (`GO`, `USE`, `SET`).
- Salida: **solo el subset** que renderiza el plugin DBML ER Diagrams.
- No inventa columnas ni convenciones por defecto; transcribe lo que indiques.

## Licencia

MIT — ver [LICENSE](LICENSE).