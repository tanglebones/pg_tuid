# pg_tuid
tuid_generate() function for postgres

## What is this?
A TUID is like a UUID (it conforms to UUID v4) but instead of being fully random it is prefixed with
the time since epoch in microseconds, a sequence number (if generating more than one per microsecond, or
waiting for clock rollback to catchup), and a node id.

## Why would use use this over a UUIDv4?
UUIDv4 is completely random, so if you have a table with a lot of entries using UUIDv4 in an index leads to
some performance issues. The main issue is new rows being inserted can cause an update to an index in a random
location. This defeats caching of index entries. By ensuring the ids are generally monotonically increasing
the entries added will be locally at the "head" of the index and multiple inserts will benefit from cache
locality. (This benefit also extends in general in that most data that is related is created at the same time.)

## tuid_generate()

`tuid_generate()` returns a `uuid` (in v4 format), but instead of being purely random it encoding the current time since epoch (in microseconds) into the msb. This generates `uuid`s that are generally monotonically increasing with time, leading to better data locality (basically, inserts should be faster as the index node being updated will be in cache more often).

## installing

`make install` and then edit your `postgresql.conf` file, adding:
    shared_preload_libraries = 'tuid'
    tuid.node_id = 0
and then restart postgresql.

If you run multiple databases set them to different `tuid.node_id` values (0 to 255) if you plan to mix data between them. This will ensure uniqueness across them. (Even without doing that odds are very unlikely you'll get a collison anyways.)

## issues

- I've no idea how to test the shmem and lwlock logic.

