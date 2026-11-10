-- Pedido del usuario: "pásame el dbml y agrupa por áreas"
CREATE TABLE ventas.cliente (
  id     INTEGER PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL
);

CREATE TABLE ventas.pedido (
  id         INTEGER PRIMARY KEY,
  cliente_id INTEGER NOT NULL REFERENCES ventas.cliente(id),
  fecha      DATE NOT NULL
);

CREATE TABLE inventario.producto (
  id     INTEGER PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL
);

CREATE TABLE inventario.bodega (
  id     INTEGER PRIMARY KEY,
  ciudad VARCHAR(60) NOT NULL
);

CREATE TABLE ventas.pedido_linea (
  pedido_id   INTEGER NOT NULL REFERENCES ventas.pedido(id),
  producto_id INTEGER NOT NULL REFERENCES inventario.producto(id),
  cantidad    INTEGER NOT NULL,
  PRIMARY KEY (pedido_id, producto_id)
);

CREATE TABLE auditoria (
  id      INTEGER PRIMARY KEY,
  detalle TEXT
);
