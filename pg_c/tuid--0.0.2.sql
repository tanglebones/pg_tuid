-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION tuid" to load this file. \quit

CREATE FUNCTION tuid_generate() RETURNS uuid
AS '$libdir/tuid', 'tuid_generate'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION tuid_ar_generate() RETURNS uuid
AS '$libdir/tuid', 'tuid_ar_generate'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION stuid_generate() RETURNS bytea
AS '$libdir/tuid', 'stuid_generate'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

