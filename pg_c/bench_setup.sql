DROP TABLE IF EXISTS b_bigserial;
DROP TABLE IF EXISTS b_tuid;
DROP EXTENSION IF EXISTS tuid;
CREATE EXTENSION tuid;

CREATE TABLE b_bigserial(
  id bigserial primary key,
  n numeric
);

CREATE TABLE b_tuid(
  id uuid default tuid_generate() primary key,
  n numeric
);

