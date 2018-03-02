DROP EXTENSION IF EXISTS tuid;
CREATE EXTENSION tuid;

SELECT tuid_generate(), tuid_generate();
EXPLAIN ANALYSE SELECT tuid_generate() FROM generate_series(1, 1000000);
SELECT tuid_ar_generate(), tuid_ar_generate();

EXPLAIN ANALYSE SELECT tuid_ar_generate() FROM generate_series(1, 1000000);

SELECT stuid_generate(), stuid_generate();
EXPLAIN ANALYSE SELECT stuid_generate() FROM generate_series(1, 1000000);
