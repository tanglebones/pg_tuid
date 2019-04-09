# pg_tuid
tuid_generate() function for postgres

## What is this?
A TUID is like a UUID (it conforms to UUID v4) but instead of being fully random (except for 6 bits for the version)
it is prefixed with the time since epoch in microseconds, a sequence number (if generating more then one per
microsecond, or waiting for clock rollback to catch up), and node id.

## Why use a TUID instead of a UUIDv4?
The high bits in a UUIDv4 are random, so if you have a table with a lot of entries using UUIDv4 in an index it leads
to some performance issues. The main issue is new rows being inserted can cause an update to an index in a random
location. This defeats caching of index entries. By ensuring the ids are generally monotonically increasing
the entries added will be locally at the "head" of the index and multiple inserts will benefit from cache
locality. (This benefit also extends in general, in that most data that is related is created at the same time.)

## tuid_generate()

`tuid_generate()` returns a new TUID, which you can store in a `uuid` field. Node id (8 bits) can be specificed via
the configuration file to ensure TUIDs created across multiple database instances can not collide, and a sequence
number (8 bits) is used here to deal with issues around clock rollback. This requires using an lw lock, which is
relatively slow.

## tuid_ar_generate()

`tuid_ar_generate()` returns a new TUID, which you can store in a `uuid` field. This version uses random for the node and sequence bits to avoid the lw lock and runs faster.

## stuid_generate()

`stuid_generate()` returns a 32 byte bytea with 64 bits of time prefix (microseconds) and 192 bits of randomness, i.e. a "Secure" TUID. This is enough randomness for use in session ids (consider storing session ids in an unlogged table, and consider using a hash index for the lookup).

## Installing

`make install` and then edit your `postgresql.conf` file, adding:

    shared_preload_libraries = 'tuid'
    tuid.node_id = 0
    
and then restart postgresql.

You need to do:

    CREATE EXTENSION tuid;

to enable the extension in your schema.

After that `tuid_generate()` (et al) will be available.

If you run multiple databases set them to have different `tuid.node_id` values (0 to 255) if you plan to mix data
between them. Using different `node_id`s will ensure the tuids have guaranteed uniqueness across them. If you plan to
generate TUIDs in client code (samples code for doing so in included in the sub-directories) you can reserve `node_id`
255 for client generated ids.

## Discussion

The use of `node_id` and `sequence_number` was included more to deal with political "it could collide, so it's unsafe" arguments that have been used against UUIDs in the past. If you _absolutely_ require the IDs be unique then use `tuid_generate`, assign each DB instance a unique `node_id` and only generate them using the DB. This is still better than using an auto-incrementing integer because the TUIDs are not in a compact space (as there are 42 bits of randomness added), and therefore cannot be easily guessed by an attacker.

In my opinion, partitioning the space by `node_id` and serializing the generation via a lock is overkill as there is no hardware in existence that can generate TUIDs fast enough to have any reasonable chance of a collision given the number of random bits in the TUID structure. This is why `tuid_ar_generate` and STUIDs are offered as well.  The `_ar` (all random) version replaces the node id and sequence number with randomness, resulting in 58 bits of randomness. The odds of a collision with 58 bits is `1:288,230,455,200,000,000`. Even if you generate 1,000 TUIDs per millisecond (roughly as fast as my machine can) the odds of a collision only rise to `1:577,038,040,655`. If you did that every second of the day (and actually had space to store the results, ~1.2GB/day for just the TUIDs) you'd start to reach the point where you'd need to move to STUIDs (with 196 bits of randomness). Very few applications are large enough to reach the point of requiring STUIDs for IDs.

The C# client code example correctly handles thread safety and clock roll back (using sequence numbering if the clock time goes backwards to allow for faster catch up).

Even though the C# client code handles clock roll back you should assume multiple clients will be talking to the database and since each is using their own clock there will be drift in the prefixes; this will be true *even* if you use a time synchronization system (NTPD, etc.) as a true synchronization is impossible. Time drift is usually not a problem unless you're relying on the order of the ids to be absolutely ascending. If you really need the IDs to be absolutely ascending user the pure SQL or C extension and have the database create the ids centrally instead of doing it in the client. *This can still fail if the DB is restarted in conjunction with the DBs clock being shifted backward in time.*

The pure SQL, ruby, and js examples set sequence to 0 or 255, but you could instead edit these to use a random number here as well.

## Issues

- Compatability with various versions of \*nix and postgresql isn't tested for the pg_c version. While I've tried
to only use code that is specific to what postgresql already supports there is always a chance it won't compile
or work on a particular \*nix or that postgresql will break/change the functions I'm depending on. If you run
into problems with any of the versions please file an issue and I will take a look at fixing it. You really only
need the C code version if you plan to generate a lot of TUIDs quickly (it is ~100x faster than the sql version).
