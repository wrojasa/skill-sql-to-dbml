CREATE TYPE order_status AS ENUM ('draft', 'paid', 'shipped');

CREATE TABLE sales."order" (
  id    INTEGER PRIMARY KEY,
  buyer VARCHAR(120) NOT NULL
);

CREATE TABLE sales.order_line (
  order_id   INTEGER NOT NULL,
  line_no    INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  qty        INTEGER NOT NULL DEFAULT 1,
  status     order_status NOT NULL DEFAULT 'draft',
  PRIMARY KEY (order_id, line_no),
  FOREIGN KEY (order_id) REFERENCES sales."order"(id),
  CONSTRAINT uq_line UNIQUE (order_id, line_no, product_id)
);
