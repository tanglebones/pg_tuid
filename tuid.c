#include <time.h>
#include <sys/time.h>
#include "postgres.h"
#include "fmgr.h"
#include "utils/guc.h"
#include "utils/builtins.h"
#include "utils/uuid.h"
#include "utils/timestamp.h"
#include "storage/lwlock.h"

/* Q. What is this?
 * A. A TUID is like a UUID (it conforms to UUID v4) but instead of being fully random it is prefixed with
 *    the time since epoch in microseconds, a sequence number (if generating more than one per microsecond, or
 *    waiting for clock rollback to catchup), and a node id.
 *
 * Q. Why would use use this over a UUIDv4?
 * A. UUIDv4 is completely random, so if you have a table with a lot of entries using UUIDv4 in an index leads to
 *    some performance issues. The main issue is new rows being inserted can cause an update to an index in a random
 *    location. This defeats caching of index entries. By ensuring the ids are generally monotonically increasing
 *    the entries added will be locally at the "head" of the index and multiple inserts will benefit from cache
 *    locality. (This benefit also extends in general in that most data that is related is created at the same time.)
 **/

PG_MODULE_MAGIC;

#define TUID_MAX_SEQ 0xFF
typedef struct tuid_state {
    LWLock *lock;
    unsigned long last;
    unsigned int seq;
} tuid_state_t;

static tuid_state_t tuid_state = {
    NULL,
    0,
    0
};
static int __node_id = 0;

/* Q. Why does seq exist?
 * A. Clock sync can (in theory) cause time to move backwards by a small amount. When that happens we fall back
 *    on sequential generation of ids (plus random because time could repeat if the server was reset and the clock
 *    was set back). Using 256 per microsecond helps prevent the id space from running into the future too much
 *    as we wait for the wall clock to catch up with our last seen time.
 *
 * An example: Say at time 1000us the clock moves back 100us and then 5 id's are generated over the next 100us. Those
 *   ids would be given seq numbers of 0,1,2,3,4 against clock 1000us (last is used to ensure our view of the clock
 *   doesn't rewind even if the system's view of the clock did). The next id is generated at time 1001us (after
 *   the system time has "caught up") with seq 0.
 **/

PG_FUNCTION_INFO_V1(tuid_generate);
void _PG_init(void);

void _PG_init(void)
{
    DefineCustomIntVariable(
        "tuid.node_id",
        "node id for use in tuid generation",
        NULL,
        &__node_id,
        0, // boot
        0, // min
        255, // max
        PGC_SIGHUP,
        0,
        NULL,
        NULL,
        NULL
    );
}

// based on GetCurrentIntegerTimestamp but without the POSTGRES_EPOCH_JDATE shift
static long get_current_unix_time_us()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000000) + tv.tv_usec;
}

Datum
tuid_generate(PG_FUNCTION_ARGS)
{
    unsigned long t_us = (unsigned long)get_current_unix_time_us();
    unsigned long last;
    unsigned int seq;
    unsigned short node_id = __node_id;

    // need a lock around this
    if (t_us <= tuid_state.last) {
        if (tuid_state.seq > TUID_MAX_SEQ) {
            seq = tuid_state.seq =0;
            last = ++tuid_state.last;
        } else {
            seq = ++tuid_state.seq;
            last = tuid_state.last;
        }
    } else {
        seq = tuid_state.seq = 0;
        last = tuid_state.last = t_us;
    }

    // 01234567-0123-0123-0123-0123456789ab\0
    // 1234567890123456789012345678901234567 890
    //          1         2         3          4
    char buffer[40];
    unsigned int rand1 = arc4random();
    unsigned int rand2 = arc4random();

    unsigned int a=(last>>32);
    unsigned int b=(last>>16)&0xffff;
    unsigned int c=0x4000 | (((last>>4)&0x0fff));
    unsigned int d=0x8000 | ((last&0xf)<<10) | ((seq>>6)&0x7f);
    unsigned int e=((seq<<10)&0xfc00) | (node_id<<2) | (rand1>>16&3);
    unsigned int f=rand2;

    snprintf(
        buffer,
        sizeof(buffer),
        "%08x-%04x-%04x-%04x-%04x%08x",
        a,b,c,d,e,f
    );

    return DirectFunctionCall1(uuid_in, CStringGetDatum(buffer));
}
