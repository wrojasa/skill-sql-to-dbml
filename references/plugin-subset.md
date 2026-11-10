# Subset DBML del plugin "DBML ER Diagrams"

Qué entiende, qué ignora y qué pierde en silencio el parser del plugin.
**Verificado contra v0.2.0** ejecutando `src/parser.ts` real sobre cada caso.
El plugin nunca muestra errores por construcciones desconocidas: las descarta.
Por eso un error de forma no avisa, simplemente falta algo en el diagrama.

Si el usuario tiene una versión anterior, ver la última sección.

## Lo que dibuja

- **Tablas**: `Table nombre [settings] {`, con `Table` en cualquier combinación de mayúsculas, o la forma corta `nombre {`. La `{` puede ir en la línea siguiente. El nombre admite comillas dobles solo en la declaración y solo si es `[A-Za-z0-9_]+`.
- **Ancho de tabla**: lo que pida su nombre o su fila más ancha (nombre, ícono, tipo y badge `NN`), con 216 px como mínimo y sin máximo. Un tipo muy largo ensancha la tabla.
- **Settings de tabla**: `headercolor: <valor>`, también `header_color`. El valor se corta en la primera coma, así que `rgb(1,2,3)` queda inválido; `#rrggbb` es lo único seguro en el plugin y en dbdiagram.io. Otros settings de tabla se ignoran.
- **Columnas**: `nombre tipo [settings]`, una por línea.
  - El tipo es todo el texto hasta el primer `[`. Admite paréntesis, comas y espacios.
  - Settings reconocidos, sin importar mayúsculas, orden ni espacios entre palabras: `pk` o `primary key`, `not null`, `note: '...'` o `note: "..."`, `ref: <op> tabla.col`.
  - El texto de una nota y los valores entre comillas de otros settings (`default: '...'`) nunca cuentan como settings.
- **Relaciones**, en cualquier parte del bloque fuera de los cuerpos de tabla, antes o después de las tablas:
  - `Ref: a.col <op> b.col` y `Ref nombre: a.col <op> b.col`.
  - La forma corta `a.col <op> b.col`.
  - La forma larga `Ref { a.col <op> b.col }`, con o sin nombre.
  - Los settings al final (`[delete: cascade]`) se ignoran.
- **Operadores**: `>`, `<`, `<>`, `-`.
- **Áreas** (`TableGroup`): ver la sección siguiente.
- **Comentarios** `// ...` y `/* ... */`: se eliminan antes de parsear, respetando las cadenas entre comillas simples.
- **Íconos**: 🔑 en columnas `pk`, 🔗 en columnas FK, badge `NN` en columnas `not null`. Una columna que es PK y FK muestra solo 🔑.

## Áreas (`TableGroup`)

```dbml
TableGroup ventas [color: #2e7d32] {
  cliente
  pedido
}
```

Lectura:

- `TableGroup` sin distinguir mayúsculas, con nombre `[A-Za-z0-9_]+`, entre comillas dobles opcionales. La `{` puede ir en la línea siguiente.
- Color en `color: #rgb` o `color: #rrggbb`. Sin color, el área es gris (`#64748b`).
- Cada línea del cuerpo con un nombre de tabla es un miembro; también se acepta `esquema.tabla`. Se ignoran las líneas `Note:`, los bloques `Note { }` y las líneas vacías.
- Un nombre que no es una tabla se ignora en silencio. Una tabla listada en dos áreas pertenece a la primera. Si dos áreas tienen el mismo nombre, se ignora la segunda. Un área sin miembros válidos no se dibuja.
- El cuerpo de un área nunca se lee como relaciones.
- `TableGroup {` sin nombre se ignora.

Dibujo:

- El layout trata cada área como contenedor: sus tablas quedan juntas y las áreas no se enciman. Con áreas, el primer layout tarda algo más y luego queda en caché.
- Área expandida: recuadro con barra de color, fondo tenue y triángulo ▾. Envuelve siempre a sus tablas y crece si una se arrastra fuera.
- Área colapsada: recuadro compacto con ▸, el nombre y el número de tablas; sus tablas no se dibujan.
  - Las relaciones hacia sus tablas llegan al recuadro, unificadas si van a la misma columna.
  - Las relaciones internas se ocultan.
  - Cada extremo conserva su marca de cardinalidad solo si todas las relaciones unificadas coinciden.
  - Esas relaciones no se pueden seleccionar ni editar mientras dure el colapso.

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

- La columna FK es la izquierda para `>`, `-` y `<>`, y la derecha para `<`. El ícono 🔗 va en esa columna.
- La marca del extremo "uno" depende de la columna FK: **barra** si es `not null` o `pk`, **círculo** si es nullable y no es PK.
- El badge `NN` solo aparece con `not null` explícito, aunque la columna sea `pk`.

## Lo que parsea pero no muestra

- **Notas** de tabla (`Note:`), de columna (`note:`) y de área. v0.2.0 no las dibuja, ni como texto ni como tooltip. Si una tabla tiene varias `Note:`, el parser guarda la última.

## Lo que ignora sin daño

- `indexes { ... }`, incluida la PK o el UNIQUE compuesto declarado ahí.
- Bloques `enum`, `Project` y `Note`, con o sin nombre. Su contenido no se lee como relaciones.
- Settings de columna `unique`, `increment` y `default: ...`.
- `as alias` en la declaración de tabla. El alias no sirve en refs: una relación escrita con el alias se descarta.

## Lo que se pierde en silencio o crea basura

| Construcción | Efecto en el plugin |
| --- | --- |
| tipo que empieza con `[` (`[int]`, estilo SSMS) | la columna desaparece con sus relaciones |
| tipo array `text[]` | el tipo se muestra como `text`, sin rastro del array |
| settings partidos en dos líneas | la columna desaparece; la segunda línea puede volverse columna fantasma |
| `,` o `;` después del `]` | la columna desaparece |
| `ref :` con espacio antes de los dos puntos, o `a . id` | la relación desaparece |
| `Ref:` dentro del cuerpo de una tabla | la relación desaparece |
| columna o extremos de ref entre comillas | la columna o la relación desaparece |
| caracteres fuera de `[A-Za-z0-9_]` en un nombre (acentos, ñ, guion) | la tabla o columna desaparece |
| `}` de cierre faltante | la tabla desaparece con sus relaciones |
| dos tablas en la misma línea | la segunda desaparece |
| dos tablas con el mismo nombre | se dibujan superpuestas |
| nota de una línea partida en dos | la segunda línea puede volverse columna fantasma |
| `Note:` sin comillas o con comillas tipográficas | la nota se pierde |
| texto `t.c > t.c` fuera de las tablas y de los bloques | relación fantasma |
| línea suelta `palabra texto` dentro del cuerpo, p. ej. `KEY idx (col)` de MySQL | columna fantasma |
| miembro de área inexistente o repetido | el plugin lo ignora, pero dbdiagram.io rechaza el bloque entero |

## Edición desde el canvas

El usuario puede cambiar el bloque desde el diagrama. En modo incremental,
el bloque que llega ya puede traer estos cambios:

- **Renombrar tabla**: cambia la declaración, las referencias `tabla.col`, sus líneas `@pos` y `@edge`, y su línea de miembro en el área.
- **Borrar tabla**: quita la declaración, sus `@pos` y `@edge`, las relaciones sueltas que la mencionan en cualquier forma, los `ref:` inline de otras tablas que apuntan a ella (la columna queda), los bloques `Ref { }` que se quedan vacíos y su línea de miembro. El área queda aunque se vacíe.
- **Renombrar columna** y **cambiar tipo**.
- **Cambiar cardinalidad**: reescribe todas las declaraciones de esa relación, inline y sueltas. La opción "One to many" escribe `<`.
- **Color de tabla**: escribe `[headercolor: #rrggbb]` en la declaración.
- **Mover un área** por su barra, o por su recuadro si está colapsada: mueve todas sus tablas y escribe sus `@pos`.
- **Colapsar o expandir un área**: escribe o borra `// @group <área> collapsed`.

Desde el canvas no se pueden crear tablas ni áreas, ni renombrar, recolorear o borrar un área, ni cambiar sus miembros. Arrastrar una tabla fuera de su área no la saca del área.

## Estado que el plugin guarda en el bloque

El plugin escribe estas líneas de comentario dentro del propio bloque. No se
escriben a mano y nunca se borran ni se modifican:

- `// @pos <tabla> <x> <y>`: posición de cada tabla que el usuario movió. Las demás se ubican solas.
- `// @edge <tabla> <col> <tabla> <col> <x1> <y1> ...`: ruta editada a mano de una relación.
- `// @group <área> collapsed`: área colapsada. Sin la línea, el área está expandida.
- `// @view <x> <y> <zoom>`: desplazamiento y zoom.
- `// @size <ancho> <alto>`: tamaño del canvas, solo si el usuario lo redimensionó.
- `// height: <n>` o `// canvas-height: <n>`: altura inicial, solo de lectura.
- `[headercolor: #rrggbb]` en la declaración, puesto desde el selector de color.

Cada vez que guarda el layout (mover, desplazar, zoom, redimensionar, editar
una ruta, colapsar), el plugin quita las líneas `// @` del cuerpo y las vuelve
a escribir al final del bloque.

## Requisitos de la nota de Obsidian

- El bloque ```` ```dbml ```` debe ir a nivel raíz. Dentro de un callout (`> `) o de un ítem de lista se dibuja, pero no se guardan posiciones ni funciona la edición.
- Un archivo `.dbml` suelto no se dibuja: el plugin solo procesa bloques de código en notas.

## Limitaciones conocidas de v0.2.0

- Las tablas nuevas se ubican con el layout automático aunque otras tengan `@pos`, así que pueden quedar encima de una tabla fijada.
- Las notas no se dibujan.
- Las áreas solo se crean y editan en el texto.

## Versiones anteriores

Las reglas de `SKILL.md` producen bloques correctos también en versiones
anteriores: PK con `not null`, tablas padre antes que hijas, solo `>` y `-`,
notas con comillas simples sin apóstrofes ni `ref:`, áreas después de las
tablas y sin bloques fuera del subset. Si el usuario reporta alguno de estos
síntomas, probablemente tiene una versión anterior y conviene que actualice.

Hasta v0.1.22:

- **Sin áreas**: `TableGroup` se ignora sin dañar el diagrama.
- **Renombrar o borrar desde el canvas** ataca una línea de miembro de área escrita antes de la declaración de su tabla.

Hasta v0.1.21, además:

- **Tablas que desaparecen**: `table` en minúscula, NBSP o BOM antes de la declaración.
- **Tablas fantasma**: `TableGroup {` o `enum {` sin nombre, y `Ref { }` en forma larga, que además pierde sus relaciones. `/* */` no es comentario.
- **Notas**: un apóstrofe trunca la nota y, en una nota de columna, el resto se lee como settings. `note: "..."` se lee como settings. `'''` y `Note { }` crean columnas fantasma. `ref: > t.c` dentro de una nota crea una relación fantasma.
- **Settings falsos**: un `default: '...'` que contiene `pk` o `not null` se lee como setting, un destino de ref llamado `pk` marca la FK como PK, una columna llamada `indexes` se descarta y `not  null` con doble espacio no se detecta.
- **Cardinalidad**: una PK que también es FK, sin `not null`, se dibuja como opcional. Con `<`, el ícono 🔗 queda en la columna izquierda y la FK real se queda sin ícono.
- **Edición desde el canvas**: renombrar o borrar una tabla ataca la primera línea que empiece con su nombre, como una tabla `user_role` o una columna `user_id` declarada antes de `Table user`. Borrar una tabla deja los `ref:` inline de otras tablas que apuntaban a ella. Si la relación está declarada inline y con `Ref:`, cambiar la cardinalidad solo cambia una de las dos.
- **Ancho fijo** de 216 px: nombres largos se montan sobre el tipo y el badge `NN`.
