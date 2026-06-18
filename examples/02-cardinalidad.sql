CREATE TABLE person (
  id         INTEGER PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  manager_id INTEGER REFERENCES person(id)          -- FK nullable (auto-relación)
);

CREATE TABLE person_profile (
  person_id INTEGER PRIMARY KEY REFERENCES person(id),  -- FK + PK => 1:1
  bio       TEXT
);
