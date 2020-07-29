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

## tuid_generate()

`tuid_generate()` returns a new TUID, which you can store in a `uuid` field.

## stuid_generate()

`stuid_generate()` returns a 32 byte bytea with 8 bytes of time prefix (microseconds) and 24 bytes of randomness, i.e. a
"Secure" TUID. This is enough randomness for use in session ids (consider storing session ids in an unlogged table, and
consider using a hash index for the lookup).

## Installing

    `make install`

You need to do:

    CREATE EXTENSION tuid;

to enable the extension in your schema.

After that `tuid_generate()` and `stuid_generate` will be available.

## Discussion

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

