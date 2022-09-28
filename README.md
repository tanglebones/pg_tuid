# pg_tuid
tuid_generate() function for postgres

## What is this?
A TUID is like a UUID (it conforms to UUID v4) but instead of being fully random (except for 6 bits for the version)
it is prefixed with the time since epoch in microseconds.

## Why use a TUID instead of a UUIDv4?

The high bits in a UUIDv4 are random, so if you have a table with a lot of entries using UUIDv4 in an index it leads
to some performance issues. The main issue is new rows being inserted can cause an update to an index in a random
location. This defeats caching of index entries. By ensuring the ids are generally monotonically increasing
the entries added will be locally at the "head" of the index and multiple inserts will benefit from cache
locality. (This benefit also extends in general, in that most data that is related is created at the same time.)

## Why use TUID/UUID over Serial

Serial ids can be guessed easily making them less secure in external APIs. If all your users start at id 1 and 
increase by ~1 for each new user, then an attacker that finds an exploit can scan the range of user ids easily. The
distance between two TUIDs generated one after another is very large by comparison, making a simple scanning attack
more expensive.

Also, all TUIDs across all environments will be unique. The means you can copy data between environments without
worrying about aliasing. I.e. if you want to copy a customer and all of their associated data from production into a
testing environment you can easily do so as none of the ids will be present in the testing environment. If you have a 
multi-deployment application and want to move data between two deployments you can avoid re-writing the ids. etc.

## `tuid6.sql` is the latest iteration.

It's just plpgsql, so you can use it on aiven.io/azure/RDS/etc.
It ignores version bits, since nothing seems to care about those anyways.

`tuid6()` returns a UUID with millisecond prefix (takes exactly 16 bytes)

```
select tuid6();
> 01838572-52b2-1e3a-51ab-119d5607e35e
```

`tuid6_to_compact(uuid)` returns the base64url encoded form (takes 22+ bytes)
```
select tuid6_to_compact(tuid6());
> AYOFdhN7r5ymN75rjTKvbg
```

`tuid6_from_compact` reverses `tuid6_to_compact`
```
select tuid6_from_compact('AYOFdhN7r5ymN75rjTKvbg');
> 01838576-137b-af9c-a637-be6b8d32af6e
```

`tuid6_tz` extracts the timestamptz from the tuid6.
```
select tuid6_tz(tuid6_from_compact('AYOFdhN7r5ymN75rjTKvbg'));
> 2022-09-28 18:57:31.515000 +00:00
```

`stuid` is a larger version stored in a `bytea`
```
select stuid();
> 0x01838586AEC20FE1143C2DF065459F7FF869FB8B71B697FDFE355E60A5CCDE61
select stuid_to_compact(stuid()); 
> AYOFhq7l3Wd34RGyviWg3vB4W5tQk1oIyna2kUajIpg
select stuid_from_compact(stuid_to_compact(stuid()));
> 0x01838586AF27F79BB34C1F71C18FECE7B2478CCFAD9C1ADBFCE695E8750AB0F2
select stuid_tz(stuid_from_compact(stuid_to_compact(stuid())));
> 2022-09-28 19:15:40.012000 +00:00
```

# Discussion

In my opinion, there is no hardware in existence that can generate TUIDs fast enough to have any reasonable chance of a
collision given the number of random bits in the TUID structure. The odds of a collision with 58 bits of randomness is
`1:288,230,455,200,000,000`. Even if you generate 1,000 TUIDs per millisecond (roughly as fast as my machine can) the
odds of a collision only rise to `1:577,038,040,655`. If you did that every second of the day (and actually had space
to store the results, ~1.2GB/day for just the TUIDs) you'd start to reach the point where you'd need to move to STUIDs
(with 196 bits of randomness). Very few applications are large enough to reach the point of requiring STUIDs for general
purpose IDs.

The code does not handle clock roll back, and you should assume multiple clients will be talking to the database and
since each is using their own clock there will be drift in the prefixes; this will be true *even* if you use a time 
synchronization system (NTPD, etc.) as a true synchronization is impossible. Time drift is usually not a problem unless
you're relying on the order of the ids to be absolutely ascending. If you really need the IDs to be absolutely ascending
use the C extension and have the database create the ids centrally instead of doing it in the client. *This can still 
fail if the DB is restarted in conjunction with the DBs clock being shifted backward in time.*

# older stuff for pre-tuid6

## tuid_generate()

`tuid_generate()` returns a new TUID, which you can store in a `uuid` field.

## stuid_generate()

`stuid_generate()` returns a 32 byte bytea with 8 bytes of time prefix (microseconds) and 24 bytes of randomness, i.e. a
"Secure" TUID. This is enough randomness for use in session ids (consider storing session ids in an unlogged table, and
consider using a hash index for the lookup).


## RNG's

As of versoin `0.2.0` I'm using `isaac64` for the RNG instead of pg's secure random number generator as it is much
faster and ID generation doesn't need to be cryptographically secure, just reasonably secure.

## Installing the `pg_c` version.

    `make install`

You need to do:

    CREATE EXTENSION tuid;

to enable the extension in your schema.

After that `tuid_generate()` and `stuid_generate` will be available.


## Performance of "pg_c" version 0.2.0

The test creates 100k rows in a table using a default id generator swapping `$ALGO/$TYPE` in the below:

```
BEGIN;

CREATE TABLE x(
  id $TYPE default $ALGO primary key,
  n numeric
);

EXPLAIN ANALYSE INSERT INTO x (n) SELECT n FROM generate_series(1, 100000) s(n);

SELECT * FROM x LIMIT 10;

ROLLBACK;
```

On my laptop running in pg13beta2 I get:

```
gen_random_uuid    | 1344 - 1400ms  | ~72.8k rows/s
stuid_generate     |  790 -  917ms  | ~111k  rows/s
tuid_generate      |  675 -  728ms  | ~142k  rows/s
bigserial          |  647 -  724ms  | ~146k  rows/s
```

Placing `tuid_generate` around the same speed (just slightly slower) as `bigserial`.

Upping n to 10 million I get:

```
gen_random_uuid    | 218750ms  | ~47.0k rows/s
stuid_generate     |  86866ms  | ~115k  rows/s
tuid_generate      |  76705ms  | ~130k  rows/s
bigserial          |  70681ms  | ~141k  rows/s
```

- `gen_random_uuid` drops to 64.6% of its 100k rate.
- `stuid_generate` got better? (probably just noise?)
- `tuid_generate` drops to 91.5% of its 100k rate.
- `bigserial` drops to 96.5% of its 100k rate.

So, as expected purely random UUIDs scale badly and using the time prefix does help mitigate the performance impact.
I suspect `bigserial` is showing better primary because `bigint` is smaller than `uuid` allowing for more data per
page of memory. Still `tuid`s are performing at over 90% of the speed of `bigserial` at the 10 million row mark.

## Updated for 0.3.0

Seeding the RNG was incorrect in 0.2.0, fixed in 0.3.0.

I've also added a script to test via `pgbench` so the impact of multiple clients creating ids at the same time
could be investigated.
 
Relevant output from my laptop:

```
... (tuid first 12.8 million)
transaction type: bench_tuid.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 4
number of transactions per client: 16
number of transactions actually processed: 128/128
latency average = 5794.685 ms
tps = 1.380576 (including connections establishing)
tps = 1.380647 (excluding connections establishing)
... (bigserial first 12.8 million)
transaction type: bench_bigserial.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 4
number of transactions per client: 16
number of transactions actually processed: 128/128
latency average = 5295.499 ms
tps = 1.510717 (including connections establishing)
tps = 1.510796 (excluding connections establishing)
... (bigserial second 12.8 million)
transaction type: bench_bigserial.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 4
number of transactions per client: 16
number of transactions actually processed: 128/128
latency average = 5386.250 ms
tps = 1.485263 (including connections establishing)
tps = 1.485338 (excluding connections establishing)
... (tuid second 12.8 million)
transaction type: bench_tuid.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 4
number of transactions per client: 16
number of transactions actually processed: 128/128
latency average = 5857.807 ms
tps = 1.365699 (including connections establishing)
tps = 1.365765 (excluding connections establishing)
```

Each "transaction" here is doing 100k inserts into a table. For the first run the final size of the table
is 12.8 million entries, and the second run adds another 12.8 million entries.

This shows `bigserial` as being _slower_ than and using `tuid_generate`. I suspect this is because `bigserial`
requires a lock across processes to ensure uniqueness, where `tuid_generate` uses a per-process RNG and
avoids locks.
