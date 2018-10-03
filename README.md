# pg_tuid
tuid_generate() function for postgres

## What is this?
A TUID is like a UUID (it conforms to UUID v4) but instead of being fully random it is prefixed with
the time since epoch in microseconds, a sequence number (if generating more than one per microsecond, or
waiting for clock rollback to catchup), and a node id.

## Why use a TUID instead of a UUIDv4?
UUIDv4 is completely random, so if you have a table with a lot of entries using UUIDv4 in an index it leads to
some performance issues. The main issue is new rows being inserted can cause an update to an index in a random
location. This defeats caching of index entries. By ensuring the ids are generally monotonically increasing
the entries added will be locally at the "head" of the index and multiple inserts will benefit from cache
locality. (This benefit also extends in general, in that most data that is related is created at the same time.)

## tuid_generate()

`tuid_generate()` returns a new TUID, which you can store in a `uuid` field.

## tuid_ar_generate()

`tuid_ar_generate()` returns a new TUID, which you can store in a `uuid` field. This version uses random for the node and seq bits avoiding the lw lock. In practice it's not any faster, but if you are not using the node and seq fields you might as well get some more randomness.

## stuid_generate()

`stuid_generate()` returns a 32 byte bytea with 64 bits of time prefix (microseconds) and 192 bits of randomness, i.e. a "secure" tuid. This is enough randomness for use in session ids (consider storing session ids in an unlogged table, and consider using a hash index for the lookup).

## installing

`make install` and then edit your `postgresql.conf` file, adding:

    shared_preload_libraries = 'tuid'
    tuid.node_id = 0
    
and then restart postgresql.

You need to do:

    CREATE EXTENSION tuid;

to enable the extension in your schema.

After that `tuid_generate()` will be available.

If you run multiple databases set them to have different `tuid.node_id` values (0 to 255) if you plan to mix data
between them. Using different `node_id`s will ensure the tuids have guaranteed uniqueness across them. If you plan to
generate TUIDs in client code (samples code for doing so in included in the sub-directories) you can reserve node_id
255 for client generated ids.

## Discussion

Including the generator node ID enforces a node-level uniqueness guarantee when combined with the timestamp and
sub-time-interval incrementing. The random bits aren't strictly needed anymore at that point, but having additional
random bits enables semi-safe generation on the client side for cases where you have no ability or desire to add
client node ID assignment code to the server.

The c# client code example correctly handles thread safety and clock roll back (using sequence numbering if the
clock time goes backwards to allow for faster catch up). The pure SQL, ruby, and js examples set sequence to 0 or
255, but you could instead use a random number here as well.

Even though the c# client code handles clock roll back you should assume multiple clients will be talking to the
database and since each is using their own clock there will be drift in the prefixes; this will be true *even* if
you use a time synchronization system (ntpd, etc.) as a true synchronization is impossible. Time drift is usually
not a problem unless you're relying on the order of the ids to be absolutely ascending; if you are then use the
pure sql or c extension and have the database create the ids centrally instead of doing it in the client.

The main benefit of generating ids in the client is the work is offloaded from the database and the client doesn't
have to wait on the database to get ids for entries. That means you can create all the entries and their relations
up front and submit them in a single batch, since the ids needed to setup the relationships are all generated
locally on the client.

## issues

- I've no idea how to test the shmem and lwlock logic. So far my manual testing indicates it is working fine, but
a more throughout real world test should be carried out.

- Compatability with various versions of \*nix and postgresql isn't tested for the pg_c version. While I've tried
to only use code that is specific to what postgresql already supports there is always a chance it won't compile
or work on a particular \*nix or that postgresql will break/change the functions I'm depending on. If you run
into problems with any of the versions please file an issue and I will take a look at fixing it. You really only
need the C code version if you plan to generate a lot of tuids quickly (it is ~100x faster than the sql version).
