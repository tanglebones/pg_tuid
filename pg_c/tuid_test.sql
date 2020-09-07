DROP EXTENSION IF EXISTS pgcrypto;
CREATE EXTENSION pgcrypto;
DROP EXTENSION IF EXISTS tuid;
CREATE EXTENSION tuid;

-- just to make sure they all work and produce different results in a single statement
SELECT gen_random_uuid(), gen_random_uuid();
SELECT tuid_generate(), tuid_generate();
SELECT stuid_generate(), stuid_generate();

-- gen_random_uuid
BEGIN;

CREATE TABLE x(
  id uuid not null default gen_random_uuid() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

BEGIN;

CREATE TABLE x(
  id uuid not null default gen_random_uuid() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

-- tuid_generate

BEGIN;

CREATE TABLE x(
  id uuid not null default tuid_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

BEGIN;

CREATE TABLE x(
  id uuid not null default tuid_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

-- stuid_generate
BEGIN;

CREATE TABLE x(
  id bytea not null default stuid_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

BEGIN;

CREATE TABLE x(
  id bytea not null default stuid_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

-- bigserial

BEGIN;

CREATE TABLE x(
  id bigserial primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

ROLLBACK;

BEGIN;

CREATE TABLE x(
  id bigserial primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;

----------------------------------------------------------------------------------------
BEGIN;

CREATE TABLE x(
  id uuid not null default tuid_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 10000000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;