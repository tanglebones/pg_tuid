DROP EXTENSION IF EXISTS tuid;
CREATE EXTENSION tuid;
SELECT tuid_set_node_id(0);
SELECT tuid_generate();
SELECT tuid_set_node_id(255);
SELECT tuid_generate();
