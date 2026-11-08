# Subset DBML del plugin "DBML ER Diagrams"

Qué entiende, qué ignora y qué pierde en silencio el parser del plugin.
**Verificado contra v0.1.21** ejecutando `src/parser.ts` real sobre cada caso.
El plugin nunca muestra errores por construcciones desconocidas: las descarta.
Por eso un error de forma no avisa, simplemente falta algo en el diagrama.

## Lo que dibuja

- **Tablas**: `Table nombre [settings] {`. La palabra `Table` es sensible a mayúsculas: con `table` en minúscula la tabla desaparece. La `{` puede ir en la línea siguiente. El nombre admite comillas dobles solo en la declaración y solo si es `[A-Za-z0-9_]+`.
- **Settings de tabla**: `headercolor: <valor>`, también `header_color`. El valor se corta en la primera coma, así que `rgb(1,2,3)` queda inválido; `#rrggbb` es lo único seguro en el plugin y en dbdiagram.io. Otros settings de tabla se ignoran.
- **Columnas**: `nombre tipo [settings]`, una por línea.
  - El tipo es todo el texto hasta el primer `[`. Admite paréntesis, comas y espacios.
  - Settings reconocidos, sin importar mayúsculas ni orden: `pk` o `primary key`, `not null`, `note: '...'`, `ref: <op> tabla.col`.
- **Relaciones**: `Ref: a.col <op> b.col`, o `a.col <op> b.col` sin el prefijo, en cualquier parte del bloque fuera de los cuerpos de tabla, antes o después de las tablas. Toleran nombre (`Ref fk_x: ...`) y settings al final (`[delete: cascade]`), que se ignoran.
- **Operadores**: `>`, `<`, `<>`, `-`.
- **Comentarios** `// ...`: se eliminan antes de parsear, respetando las cadenas entre comillas simples.
- **Íconos**: 🔑 en columnas `pk`, 🔗 en columnas FK, badge `NN` en columnas `not null`. Una columna que es PK y FK muestra solo 🔑.

## Validación de relaciones

- Una relación se descarta en silencio si su tabla o su columna de origen o destino no existe. La comparación distingue mayúsculas. Al descartarse, la columna FK pierde también su ícono 🔗.
- Las relaciones idénticas, con el mismo operador y sentido, se deduplican. Si el mismo par aparece con otro operador o en sentido inverso, se dibujan dos aristas.

## Cardinalidad (derivada, no escrita)

| Operador | Extremo izquierdo | Extremo derecho |
| --- | --- | --- |
| `a.x > b.y` | muchos (pata de gallo) | uno |
| `a.x < b.y` | uno | muchos |
| `a.x - b.y` | uno | uno |
| `a.x <> b.y` | muchos | muchos |

- La marca del extremo "uno" depende de la columna FK: **barra** si es `not null`, **círculo** si es nullable. Para `>` y `-` la FK es la columna izquierda; para `<`, la derecha.
- `pk` no implica `not null`. Una PK que también es FK, sin `not null`, se dibuja como opcional.
- El ícono 🔗 se pone siempre en la columna izquierda, sin importar el operador. Con `<` queda en la columna PK y la FK real se queda sin ícono. Por eso la skill solo emite `>` y `-`.

## Lo que parsea pero no muestra

- **Notas** de tabla (`Note:`) y de columna (`note:`). v0.1.21 no las dibuja, ni como texto ni como tooltip. Si una tabla tiene varias `Note:`, el parser guarda la última.

## Lo que ignora sin daño

- `indexes { ... }`, incluida la PK o el UNIQUE compuesto declarado ahí.
- Bloques con nombre: `enum x { }`, `TableGroup x { }`, `Project x { }`.
- Settings de columna `unique`, `increment` y `default: ...`. Excepción: si el valor de `default` contiene `pk`, `not null` o `ref: > t.c`, el plugin lo lee como setting.
- `as alias` en la declaración de tabla. El alias no sirve en refs: una relación escrita con el alias se descarta.

## Lo que se pierde en silencio o crea basura

| Construcción | Efecto en el plugin |
| --- | --- |
| tipo que empieza con `[` (`[int]`, estilo SSMS) | la columna desaparece con sus relaciones |
| tipo array `text[]` | el tipo se muestra como `text`, sin rastro del array |
| settings partidos en dos líneas | la columna desaparece; la segunda línea puede volverse columna fantasma |
| `,` o `;` después del `]` | la columna desaparece |
| `not  null` con doble espacio o tabulador | no se detecta el `not null` |
| `ref :` con espacio antes de los dos puntos, o `a . id` | la relación desaparece |
| `Ref:` dentro del cuerpo de una tabla | la relación desaparece |
| columna o ref con nombre entre comillas | la columna o la relación desaparece |
| caracteres fuera de `[A-Za-z0-9_]` en un nombre (acentos, ñ, guion) | la tabla o columna desaparece |
| NBSP antes o después de `Table`, o BOM al inicio de la línea | la tabla desaparece |
| `}` de cierre faltante | la tabla desaparece con sus relaciones |
| dos tablas en la misma línea | la segunda desaparece |
| dos tablas con el mismo nombre | se dibujan superpuestas |
| `Note { ... }` en bloque | columna fantasma llamada `Note` |
| `Note: '''...'''` | nota vacía; en multilínea, cada línea es una columna fantasma |
| nota de una línea partida en dos | la segunda línea puede volverse columna fantasma |
| apóstrofe dentro de una nota | la nota se trunca; en una nota de columna, el resto se lee como settings |
| `note: "..."` con comillas dobles | el texto se lee como settings: puede activar `pk` o `not null` |
| `ref: > t.c` dentro de una nota de columna | relación fantasma |
| texto `t.c > t.c` fuera de las tablas | relación fantasma |
| destino de ref con tabla o columna llamada `pk` | la columna FK se marca como PK |
| columna llamada `indexes` | la columna desaparece |
| `/* ... */` | no es comentario: lo que tenga dentro se parsea |
| `TableGroup {` o `enum {` sin nombre | tabla fantasma vacía |

## Estado que el plugin guarda en el bloque

El plugin escribe estas líneas de comentario dentro del propio bloque. No se
escriben a mano y nunca se borran ni se modifican:

- `// @pos <tabla> <x> <y>`: posición de cada tabla que el usuario movió. Las demás se ubican solas.
- `// @edge <tabla> <col> <tabla> <col> <x1> <y1> ...`: ruta editada a mano de una relación.
- `// @view <x> <y> <zoom>`: desplazamiento y zoom.
- `// @size <ancho> <alto>`: tamaño del canvas, solo si el usuario lo redimensionó.
- `// height: <n>` o `// canvas-height: <n>`: altura inicial, solo de lectura.
- `[headercolor: #rrggbb]` en la declaración, puesto desde el selector de color.

Cada vez que guarda el layout (mover, desplazar, zoom, redimensionar, editar
una ruta), el plugin quita las líneas `// @` del cuerpo y las vuelve a escribir
al final del bloque. Renombrar o borrar una tabla desde el canvas también
actualiza sus `@pos` y `@edge`.

## Requisitos de la nota de Obsidian

- El bloque ```` ```dbml ```` debe ir a nivel raíz. Dentro de un callout (`> `) o de un ítem de lista se dibuja, pero no se guardan posiciones ni funciona la edición.
- Un archivo `.dbml` suelto no se dibuja: el plugin solo procesa bloques de código en notas.

## Comportamientos conocidos de v0.1.21

- **Renombrar o borrar una tabla desde el canvas** busca la primera línea que empiece con su nombre. Si antes de la declaración hay una tabla o columna que empieza igual (`user_role`, `user_id` antes de `Table user`), modifica esa línea. Mitigación: tablas padre antes que sus hijas.
- **Borrar una tabla** quita sus líneas `Ref:` sueltas, pero no los `ref:` inline de otras tablas que apuntan a ella. El plugin los descarta en silencio; dbdiagram.io rechaza el bloque.
- **Menú de cardinalidad**: "One to many" escribe `<`, con el problema del ícono 🔗 descrito arriba. Si la misma relación está declarada inline y con `Ref:`, solo cambia la línea `Ref:` y quedan dos aristas.
- **Tablas nuevas** se ubican con el layout automático aunque otras tengan `@pos`, así que pueden quedar encima de una tabla fijada.
