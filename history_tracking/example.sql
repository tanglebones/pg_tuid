CREATE EXTENSION IF NOT EXISTS tuid;

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
  CREATE TABLE %I.%I (
    entry %I.%I
  ) INHERITS (%I.tx_history);', schema_name, table_name || '_history', schema_name, table_name, schema_name);

  -- don't allow any edits to history
  EXECUTE FORMAT('
    CREATE TRIGGER %I
    BEFORE UPDATE OR DELETE OR TRUNCATE
    ON %I.%I
    EXECUTE PROCEDURE prevent_change();
  ', table_name || '_nochng', schema_name, table_name || '_history');

  EXECUTE FORMAT($FUNC$
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

    INSERT INTO %I.%I (id, table_schema, table_name, txid, who, op, entry) VALUES (NEW.%I, TG_TABLE_SCHEMA, TG_TABLE_NAME, txid, who, 'U', NEW);
    RETURN NEW;
  END IF;

  IF tg_op = 'INSERT'
  THEN
    INSERT INTO %I.%I (id, table_schema, table_name, txid, who, op, entry) VALUES (NEW.%I, TG_TABLE_SCHEMA, TG_TABLE_NAME, txid, who, 'I', NEW);
    RETURN NEW;
  END IF;

  IF tg_op = 'DELETE'
  THEN
    INSERT INTO %I.%I (id, table_schema, table_name, txid, who, op, entry) VALUES (OLD.%I, TG_TABLE_SCHEMA, TG_TABLE_NAME, txid, who, 'D', OLD);
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$X$;
  $FUNC$,
    schema_name, table_name || '_htrig',
    id_column_name, id_column_name,
    schema_name, table_name || '_history', id_column_name,
    schema_name, table_name || '_history', id_column_name,
    schema_name, table_name || '_history', id_column_name
  );

  -- hook up the trigger
  EXECUTE FORMAT('
  CREATE TRIGGER %I
    BEFORE UPDATE OR DELETE OR INSERT
    ON %I.%I
    FOR EACH ROW EXECUTE PROCEDURE %I.%I();
  ', table_name || '_tracked', schema_name, table_name, schema_name, table_name || '_htrig');
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


