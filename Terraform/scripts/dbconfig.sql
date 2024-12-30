-- Crear la base de datos y el usuario
CREATE DATABASE user_db;

CREATE USER my_user WITH PASSWORD 'user_pwd';

GRANT ALL PRIVILEGES ON DATABASE user_db TO my_user;

-- Conectarse a la base de datos recién creada
\c user_db

-- Crear la tabla
CREATE TABLE test_results (
    name VARCHAR(50),
    id INT,
    birth_date DATE,
    score DECIMAL(5, 2),
    grade CHAR(1),
    passed BOOLEAN
);

COPY test_results(name, id, birth_date, score, grade, passed)
FROM '/tmp/test_results.csv'
DELIMITER ','
CSV HEADER;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE test_results TO my_user;