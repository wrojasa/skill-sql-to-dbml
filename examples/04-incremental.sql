CREATE TABLE vendedor (
  id     INTEGER PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  zona   VARCHAR(30)
);

ALTER TABLE pedido ADD CONSTRAINT fk_pedido_vendedor
  FOREIGN KEY (vendedor_id) REFERENCES vendedor(id);
