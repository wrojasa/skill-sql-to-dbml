CREATE TABLE person (
  id         INTEGER PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  manager_id INTEGER REFERENCES person(id)              -- jefe directo, NULL si no tiene
);

CREATE TABLE person_profile (
  person_id INTEGER PRIMARY KEY REFERENCES person(id),  -- perfil de la misma persona (1:1)
  bio       TEXT
);
