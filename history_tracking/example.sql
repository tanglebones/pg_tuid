
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION tuid_generate()
  RETURNS UUID AS $$
DECLARE
  ct  BIGINT;
  seq BIGINT;
  nid BIGINT;
  r0  BIGINT;
  r1  BIGINT;
  ax  BIGINT;
  bx  BIGINT;
  cx  BIGINT;
  dx  BIGINT;
  ex  BIGINT;
  fx  BIGINT;
  ret VARCHAR;
BEGIN
  seq := 255;
  nid := 255;
  ct := extract(EPOCH FROM clock_timestamp() AT TIME ZONE 'utc') * 1000000;
  r0 := (random() * 4294967295 :: BIGINT) :: BIGINT;
  r1 := (random() * 4294967295 :: BIGINT) :: BIGINT;

  ax := ct >> 32;
  bx := ct >> 16 & x'FFFF' :: INT;
  cx := x'4000' :: INT | ((ct >> 4) & x'0FFF' :: INT);
  dx := x'8000' :: INT | ((ct & x'F' :: INT) << 10) | (seq << 2) | (nid >> 6);
  ex := ((nid & x'3F' :: INT) << 2) | (r0 & x'3FF' :: INT);
  fx := r1;

  ret :=
    LPAD(TO_HEX(ax),8,'0') ||
    LPAD(TO_HEX(bx),4,'0') ||
    LPAD(TO_HEX(cx),4,'0') ||
    LPAD(TO_HEX(dx),4,'0') ||
    LPAD(TO_HEX(ex),4,'0') ||
    LPAD(TO_HEX(fx),8,'0');

  return ret :: UUID;
END;
$$ LANGUAGE plpgsql;

-- all random version
CREATE OR REPLACE FUNCTION tuid_ar_generate()
  RETURNS UUID AS $$
DECLARE
  ct  BIGINT;
  seq BIGINT;
  nid BIGINT;
  r0  BIGINT;
  r1  BIGINT;
  r2  BIGINT;
  ax  BIGINT;
  bx  BIGINT;
  cx  BIGINT;
  dx  BIGINT;
  ex  BIGINT;
  fx  BIGINT;
  ret VARCHAR;
BEGIN
  r2 := (random() * 4294967295 :: BIGINT) :: BIGINT;
  seq := r2 & x'FF' :: INT;
  nid := (r2 >> 8) & x'FF' :: INT;
  ct := extract(EPOCH FROM clock_timestamp() AT TIME ZONE 'utc') * 1000000;
  r0 := (random() * 4294967295 :: BIGINT) :: BIGINT;
  r1 := (random() * 4294967295 :: BIGINT) :: BIGINT;

  ax := ct >> 32;
  bx := ct >> 16 & x'FFFF' :: INT;
  cx := x'4000' :: INT | ((ct >> 4) & x'0FFF' :: INT);
  dx := x'8000' :: INT | ((ct & x'F' :: INT) << 10) | (seq << 2) | (nid >> 6);
  ex := ((nid & x'3F' :: INT) << 2) | (r0 & x'3FF' :: INT);
  fx := r1;

  ret :=
    LPAD(TO_HEX(ax),8,'0') ||
    LPAD(TO_HEX(bx),4,'0') ||
    LPAD(TO_HEX(cx),4,'0') ||
    LPAD(TO_HEX(dx),4,'0') ||
    LPAD(TO_HEX(ex),4,'0') ||
    LPAD(TO_HEX(fx),8,'0');

  return ret :: UUID;
END;
$$ LANGUAGE plpgsql;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION stuid_generate()
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

DROP TABLE IF EXISTS tx_history CASCADE;
DROP TABLE IF EXISTS test CASCADE;
DROP TABLE IF EXISTS test_history CASCADE;

RESET "audit.user";

--------------------------------------------------------------
-- util function

CREATE OR REPLACE FUNCTION prevent_change()
  RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Records in table % cannot be %d', TG_TABLE_NAME, lower(TG_OP);
END;
$$;

--------------------------------------------------------------
-- table to graft history onto
CREATE TABLE test (
  test_id UUID NOT NULL DEFAULT tuid_ar_generate() PRIMARY KEY,
  foo VARCHAR,
  bar VARCHAR
);

---------------------------------------------------------------
-- history tracking stuff

CREATE TABLE tx_history (
  txid BIGINT,
  table_schema VARCHAR NOT NULL,
  table_name VARCHAR NOT NULL,
  id UUID NOT NULL,
  rev UUID NOT NULL DEFAULT tuid_ar_generate() PRIMARY KEY,
  who VARCHAR NOT NULL,
  tz TIMESTAMPTZ NOT NULL DEFAULT now(),
  op CHAR CHECK (op = ANY (ARRAY ['I' :: CHAR, 'U' :: CHAR, 'D' :: CHAR]))
);

-- function to setup history table and triggers to prevent history alteration and tracking of changes
CREATE OR REPLACE FUNCTION add_history_to_table(schema_name VARCHAR, table_name VARCHAR, id_column_name VARCHAR)
  RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
BEGIN
  -- history of table data for test
  EXECUTE FORMAT('
  DROP TABLE IF EXISTS %I.%I;
  CREATE TABLE %I.%I (
    entry JSONB
  ) INHERITS (%I.tx_history);',
    schema_name, table_name || '_h' ,
    schema_name, table_name || '_h',
    schema_name);

  EXECUTE FORMAT('
    CREATE INDEX %I ON %I.%I (id, entry);
  ',
    table_name || '_hi', schema_name, table_name || '_h'
  );

  -- don't allow any edits to history
  EXECUTE FORMAT('
    DROP TRIGGER IF EXISTS %I ON %I.%I;
    CREATE TRIGGER %I
    BEFORE UPDATE OR DELETE OR TRUNCATE
    ON %I.%I
    EXECUTE PROCEDURE prevent_change();
  ', table_name || '_no', schema_name, table_name || '_h', table_name || '_no', schema_name, table_name || '_h');

  EXECUTE FORMAT($FUNC$
  DROP FUNCTION IF EXISTS %I.%I();
  CREATE OR REPLACE FUNCTION %I.%I()
    RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $X$
  DECLARE
    who VARCHAR;
    txid BIGINT;
  BEGIN
    SELECT current_setting('audit.user')
    INTO who;
    IF who IS NULL OR who = ''
    THEN
      RAISE EXCEPTION 'audit.user is not set.';
    END IF;

    txid = txid_current_if_assigned();
    IF txid IS NOT NULL
    THEN
      txid = TXID_SNAPSHOT_XMIN(txid_current_snapshot());
    ELSE
      txid = txid_current();
    END IF;

    IF tg_op = 'UPDATE'
    THEN
      IF (OLD.%I != NEW.%I)
      THEN
        RAISE EXCEPTION 'id cannot be changed';
      END IF;

      INSERT INTO %I.%I (id, table_schema, table_name, txid, who, op, entry) VALUES (NEW.%I, TG_TABLE_SCHEMA, TG_TABLE_NAME, txid, who, 'U', to_jsonb(NEW));
      RETURN NEW;
    END IF;

    IF tg_op = 'INSERT'
    THEN
      INSERT INTO %I.%I (id, table_schema, table_name, txid, who, op, entry) VALUES (NEW.%I, TG_TABLE_SCHEMA, TG_TABLE_NAME, txid, who, 'I', to_jsonb(NEW));
      RETURN NEW;
    END IF;

    IF tg_op = 'DELETE'
    THEN
      INSERT INTO %I.%I (id, table_schema, table_name, txid, who, op, entry) VALUES (OLD.%I, TG_TABLE_SCHEMA, TG_TABLE_NAME, txid, who, 'D', to_jsonb(OLD));
      RETURN OLD;
    END IF;

    RETURN NULL;
  END;
  $X$;
  $FUNC$,
    schema_name, table_name || '_htrig',
    schema_name, table_name || '_htrig',
    id_column_name, id_column_name,
    schema_name, table_name || '_h', id_column_name,
    schema_name, table_name || '_h', id_column_name,
    schema_name, table_name || '_h', id_column_name
  );

  -- hook up the trigger
  EXECUTE FORMAT('
  DROP TRIGGER IF EXISTS %I ON %I.%I;
  CREATE TRIGGER %I
    BEFORE UPDATE OR DELETE OR INSERT
    ON %I.%I
    FOR EACH ROW EXECUTE PROCEDURE %I.%I();
  ', table_name || '_tracked', schema_name, table_name || '_htrig',
    table_name || '_tracked',
    schema_name, table_name,
    schema_name, table_name || '_htrig');
END;
$$;

SELECT add_history_to_table('public', 'test', 'test_id');

------------------------------------------------
-- some testing of the result

BEGIN;

SET "audit.user" TO 'A';

INSERT INTO test (foo) VALUES ('bar1');
INSERT INTO test (foo) VALUES ('arg1');

COMMIT;

BEGIN;
SET "audit.user" TO 'B';

UPDATE test
SET foo = 'bar2'
WHERE test_id IN (SELECT test_id
FROM test
WHERE foo = 'bar1');

BEGIN;

UPDATE test
SET foo = 'bar3'
WHERE test_id IN (SELECT test_id
FROM test
WHERE foo = 'bar2');

COMMIT;

COMMIT;

SELECT *
FROM test;

BEGIN;

SET "audit.user" TO 'A';

DELETE FROM test;

SELECT *
FROM test_history;

SELECT *
FROM test;

COMMIT;

SELECT *
FROM tx_history;

