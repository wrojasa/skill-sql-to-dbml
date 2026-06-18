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
