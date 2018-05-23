DROP EXTENSION IF EXISTS pgcrypto;
CREATE EXTENSION pgcrypto;
DROP EXTENSION IF EXISTS tuid;
CREATE EXTENSION tuid;

SELECT tuid_generate(), tuid_generate();
EXPLAIN ANALYSE SELECT tuid_generate() FROM generate_series(1, 1000000);
SELECT tuid_ar_generate(), tuid_ar_generate();

EXPLAIN ANALYSE SELECT tuid_ar_generate() FROM generate_series(1, 1000000);

SELECT stuid_generate(), stuid_generate();
EXPLAIN ANALYSE SELECT stuid_generate() FROM generate_series(1, 1000000);

BEGIN;

CREATE TABLE x(
  id uuid not null default gen_random_uuid() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

ROLLBACK;

BEGIN;

CREATE TABLE x(
  id uuid not null default tuid_ar_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

ROLLBACK;

BEGIN;

CREATE TABLE x(
  id uuid not null default tuid_generate() primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

ROLLBACK;



