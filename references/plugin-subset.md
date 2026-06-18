# Subset DBML soportado por el plugin "DBML ER Diagrams"

Qué entiende y qué ignora el motor del plugin. Sirve para no emitir nada que no
se dibuje. (Basado en el parser del plugin; ante la duda, mantenerse en lo
listado como "soportado".)

## Soportado

- **Tablas**: `Table nombre [settings] { ... }`. El nombre se toma como
  identificador simple (`[A-Za-z0-9_]`); las comillas se ignoran. Se acepta
  `as alias` pero el plugin usa el nombre.
- **Settings de tabla**: `headercolor: #hex` (color del encabezado). Otros
  settings se ignoran sin romper.
- **Columnas**: `nombre tipo [settings]`.
  - `tipo`: cualquier texto hasta los settings; admite paréntesis, coma y
    espacios (`decimal(12,2)`, `varchar(255)`).
  - settings reconocidos: `pk` / `primary key`, `not null`, `note: '...'`,
    `ref: <op> tabla.col` (relación inline).
- **Note de tabla**: línea `Note: '...'` dentro del cuerpo (comillas simples).
- **Relaciones sueltas**: `Ref: a.col <op> b.col` o `a.col <op> b.col`.
- **Operadores de relación**: `>` `<` `<>` `-`.
- **Comentarios**: `// ...` (se eliminan antes de parsear). El plugin usa
  `// @pos`, `// @view` y `// height:` / `// canvas-height:` para su propio
  estado; no colisionar con esos prefijos.

## Cardinalidad (derivada, no escrita)

- `>`: `from` = muchos (pata de gallo), `to` = uno.
- `<`: `to` = muchos.
- `<>`: ambos lados muchos.
- `-`: ambos lados uno (1:1).
- En `>`, `-`, la columna FK es la de `from`; en `<`, la de `to`.
- Lado "uno": **barra** si la columna FK es `not null`, **círculo** si es
  nullable. → conservar `not null`/nullable de la FK.
- Íconos: 🔑 en columnas `pk`, 🔗 en columnas FK; badge `NN` en columnas `not null`.

## Ignorado o no soportado (no emitir)

- `indexes { ... }` → se ignora por completo (incluida PK/única compuesta ahí declarada).
- `enum { ... }` / tipos enumerados → no se parsean.
- `TableGroup`, `Project`, sticky notes de dbdiagram → no soportado.
- Settings de columna fuera de la lista: `unique`, `increment`, `default: ...` → se ignoran (mejor no emitirlos).
- Referencias **multi-columna** (`ref: > t.(a,b)`) → no soportado.
- Nombres con espacios o caracteres no `[A-Za-z0-9_]` → no parsean bien; usar snake_case.

## Estado gestionado por el plugin (no escribir a mano)

- `// @pos <tabla> x y` → posición guardada de cada tabla.
- `// @view x y k` → vista (pan/zoom) guardada.
- `[headercolor: #hex]` puesto desde la UI.

En modo incremental, **preservar** estas líneas/atributos: el plugin los escribe
y los lee para mantener el diagrama como el usuario lo dejó.
