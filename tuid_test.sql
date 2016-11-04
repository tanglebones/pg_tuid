DROP EXTENSION IF EXISTS tuid;
CREATE EXTENSION tuid;

SELECT tuid_generate();
SELECT tuid_generate(), tuid_generate();
