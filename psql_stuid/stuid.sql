CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION func.stuid_generate()
  RETURNS BYTEA
LANGUAGE plpgsql
AS $$
DECLARE
  ct BIGINT;
  ret BYTEA;
BEGIN
  ct := extract(EPOCH FROM clock_timestamp() AT TIME ZONE 'utc') * 1000000;
  ret := decode(LPAD(TO_HEX(ct),16,'0'),'hex') || gen_random_bytes(24);
  RETURN ret;
END;
$$;
