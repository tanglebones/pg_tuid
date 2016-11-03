# pg_tuid
tuid_generate() function for postgres

## tuid_generate()

`tuid_generate()` returns a `uuid` (in v4 format), but instead of being purely random it encoding the current time since epoch (in microseconds) into the msb. This generates `uuid`s that are generally monotonically increasing with time, leading to better data locality (basically, inserts should be faster as the index node being updated will be in cache more often).

## issues

- I'm not sure what locking system I should use for handling updates to `__last`, `__seq`, and `__node_id`.
- I'm not sure how to access `set` variables and am using `tuid_set_node_id(integer)` and `tuid_get_node_id():integer` for this currently.
