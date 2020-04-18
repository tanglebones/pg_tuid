#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include "postgres.h"
#include "fmgr.h"
#include "utils/guc.h"
#include "utils/builtins.h"
#include "utils/uuid.h"
#include "utils/timestamp.h"
#include "utils/backend_random.h"
#include "storage/lwlock.h"
#include "storage/lmgr.h"
#include "storage/ipc.h"
#include "storage/shmem.h"
#include "miscadmin.h"

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
    uint64 last;
    unsigned int seq;
} tuid_state_t;

static tuid_state_t * tuid_state;
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
PG_FUNCTION_INFO_V1(tuid_ar_generate);
PG_FUNCTION_INFO_V1(stuid_generate);
void _PG_init(void);
void _PG_fini(void);
static Size tuid_state_memsize(void);
static void tuid_shmem_startup(void);
unsigned int random_unsigned_int(void);

static Size
tuid_state_memsize(void) {
    Size size;
    size = MAXALIGN(sizeof(tuid_state_t));
    return size;
}
static shmem_startup_hook_type prev_shmem_startup_hook = NULL;

#define TUID_SHMEM_NAME "pg_tuid"

void _PG_init(void)
{
    elog(LOG, "pg_tuid init");

    DefineCustomIntVariable(
        "tuid.node_id",
        "node id for use in tuid generation",
        NULL,
        &__node_id,
        0, /* boot */
        0, /* min */
        255, /* max */
        PGC_SIGHUP,
        0,
        NULL,
        NULL,
        NULL
    );
    RequestAddinShmemSpace(tuid_state_memsize());
    RequestNamedLWLockTranche(TUID_SHMEM_NAME, 1);

    prev_shmem_startup_hook = shmem_startup_hook;
    shmem_startup_hook = tuid_shmem_startup;
}

void _PG_fini(void)
{
    if (!process_shared_preload_libraries_in_progress)
        return;
    shmem_startup_hook = prev_shmem_startup_hook;
}

static void tuid_shmem_startup()
{
    elog(LOG, "pg_tuid tuid_shmem_startup");
    if (!tuid_state) {
        bool found;
        tuid_state = NULL;
        if (prev_shmem_startup_hook) {
            prev_shmem_startup_hook();
        }
        LWLockAcquire(AddinShmemInitLock, LW_EXCLUSIVE);
        tuid_state = ShmemInitStruct(TUID_SHMEM_NAME, sizeof(tuid_state_t), &found);
        if (tuid_state == NULL) {
          elog(ERROR, "ShmemInitStruct returned NULL");
        }
        if (!found) {
            // !found means the structure was just allocated, so initialize it.
            tuid_state->last=0;
            tuid_state->seq=0;
            tuid_state->lock=&(GetNamedLWLockTranche(TUID_SHMEM_NAME))->lock;
	    if (tuid_state->lock == NULL) {
              elog(ERROR, "GetNamedLWLockTranche returned NULL");
            }
        }
        LWLockRelease(AddinShmemInitLock);
    }
}

#ifdef _POSIX_TIMERS
    /* #pragma message ( "Using clock_gettime" ) */

    static uint64 get_current_unix_time_us()
    {
        struct timespec ts;
        uint64 sec;
        uint64 nsec;

        clock_gettime(CLOCK_REALTIME, &ts);
        sec = (uint64)ts.tv_sec;
        nsec = (uint64)ts.tv_nsec;
        return (sec * 1000000) + nsec/1000;
    }
#else
    /* #pragma message ( "Using gettimeofday" ) */
    /* based on GetCurrentIntegerTimestamp but without the POSTGRES_EPOCH_JDATE shift */
    static uint64 get_current_unix_time_us()
    {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        uint64 sec = (uint64)tv.tv_sec;
        uint64 usec = (uint64)tv.tv_usec;
        return (sec * 1000000) + usec;
    }
#endif

unsigned int random_unsigned_int(void)
{
  unsigned int r;
  if (!pg_backend_random((char*)&r, sizeof(r)))
  {
    elog(ERROR, "tuid_generate: pg_backend_random failed!");
    return 0;
  }
  return r;
}

Datum
tuid_generate(PG_FUNCTION_ARGS)
{
    uint8* buffer = (uint8*) palloc(UUID_LEN);

    uint64 t_us = get_current_unix_time_us();
    uint64 last;
    unsigned int seq;
    unsigned short node_id = __node_id&0xff;
    unsigned int rand1;
    unsigned int rand2;

    unsigned int a;
    unsigned int b;
    unsigned int c;
    unsigned int d;
    unsigned int e;
    unsigned int f;

    if (tuid_state == NULL) {
      elog(ERROR, "tuid_generate: tuid_state is NULL! did you remember to add 'tuid' to the shared_preload_libraries?");
    }

    LWLockAcquire(tuid_state->lock, LW_EXCLUSIVE);
    if (t_us <= tuid_state->last) {
        if (tuid_state->seq > TUID_MAX_SEQ) {
            seq = tuid_state->seq =0;
            last = ++tuid_state->last;
        } else {
            seq = ++tuid_state->seq;
            last = tuid_state->last;
        }
    } else {
        seq = tuid_state->seq = 0;
        last = tuid_state->last = t_us;
    }
    LWLockRelease(tuid_state->lock);

    /*
      01234567-0123-0123-    0     1     2     3 -    0     1 23456789ab\0
      TTTTTTTT-TTTT-4TTT-(10tt)(ttss)(ssss)(ssnn)-(nnnn)(nnrr)RRRRRRRRRR\0

      The 4 and 10 hard coded into the above are the version bits for UUID4
    */
    rand1 = random_unsigned_int();
    rand2 = random_unsigned_int();

    a = (last>>32); /* time bits 63..32 */
    b = (last>>16)&0xffff; /* time bits 31..16 */
    c = 0x4000 | (((last>>4)&0x0fff)); /* 0100b | time bits 15..4 */
    d = 0x8000 | ((last&0xf)<<10) | (seq<<2) | ( node_id>>6); /* 10b | time bits 3..0 | seq bits 7..0 | node_id bits 7..6 */
    e = ((node_id&0x3f)<<2) | (rand1&0x3ff); /* node_id bits 5..0 | rand1 bits 10..0 */
    f = rand2; /* 32 bits of rand2 */

    /*
      64 bits of time
      6 bits of UUID version markers
      8 bits of seq
      8 bits of node_id
      42 bits of random
    */

    buffer[0] = (a>>24)&0xff;
    buffer[1] = (a>>16)&0xff;
    buffer[2] = (a>>8)&0xff;
    buffer[3] = a&0xff;

    buffer[4] = (b>>8)&0xff;
    buffer[5] = b&0xff;

    buffer[6] = (c>>8)&0xff;
    buffer[7] = c&0xff;

    buffer[8] = (d>>8)&0xff;
    buffer[9] = d&0xff;

    buffer[10] = (e>>8)&0xff;
    buffer[11] = e&0xff;

    buffer[12] = (f>>24)&0xff;
    buffer[13] = (f>>16)&0xff;

    buffer[14] = (f>>8)&0xff;
    buffer[15] = f&0xff;

    PG_RETURN_UUID_P((pg_uuid_t *) buffer);
}

Datum
tuid_ar_generate(PG_FUNCTION_ARGS)
{
    uint8* buffer = (uint8*) palloc(UUID_LEN);
    uint64 t_us;
    unsigned int seq;
    unsigned int node_id;
    unsigned int rand1;
    unsigned int rand2;

    unsigned int a;
    unsigned int b;
    unsigned int c;
    unsigned int d;
    unsigned int e;
    unsigned int f;

    t_us = get_current_unix_time_us();
    seq = random_unsigned_int();
    node_id = seq >> 16;
    seq &= 0xff;
    node_id &= 0xff;

    if (tuid_state == NULL) {
      elog(ERROR, "tuid_generate: tuid_state is NULL! did you remember to add 'tuid' to the shared_preload_libraries?");
    }

    /*
      01234567-0123-0123-    0     1     2     3 -    0     1 23456789ab\0
      TTTTTTTT-TTTT-4TTT-(10tt)(ttss)(ssss)(ssnn)-(nnnn)(nnrr)RRRRRRRRRR\0

      The 4 and 10 hard coded into the above are the version bits for UUID4
    */
    rand1 = random_unsigned_int();
    rand2 = random_unsigned_int();

    a = (t_us>>32); /* time bits 63..32 */
    b = (t_us>>16)&0xffff; /* time bits 31..16 */
    c = 0x4000 | (((t_us>>4)&0x0fff)); /* 0100b | time bits 15..4 */
    d = 0x8000 | ((t_us&0xf)<<10) | (seq<<2) | ( node_id>>6); /* 10b | time bits 3..0 | seq bits 7..0 | node_id bits 7..6 */
    e = ((node_id&0x3f)<<10) | (rand1&0x3ff); /* node_id bits 5..0 | rand1 bits 10..0 */
    f = rand2; /* 32 bits of rand2 */

    /*
      64 bits of time
      6 bits of UUID version markers
      8 bits of random
      8 bits of random
      42 bits of random
    */

    buffer[0] = (a>>24)&0xff;
    buffer[1] = (a>>16)&0xff;
    buffer[2] = (a>>8)&0xff;
    buffer[3] = a&0xff;

    buffer[4] = (b>>8)&0xff;
    buffer[5] = b&0xff;

    buffer[6] = (c>>8)&0xff;
    buffer[7] = c&0xff;

    buffer[8] = (d>>8)&0xff;
    buffer[9] = d&0xff;

    buffer[10] = (e>>8)&0xff;
    buffer[11] = e&0xff;

    buffer[12] = (f>>24)&0xff;
    buffer[13] = (f>>16)&0xff;

    buffer[14] = (f>>8)&0xff;
    buffer[15] = f&0xff;

    PG_RETURN_UUID_P((pg_uuid_t *) buffer);
}

Datum
stuid_generate(PG_FUNCTION_ARGS)
{
    bytea *res;
    int length = VARHDRSZ + 32;
    res = palloc(length);
    SET_VARSIZE(res, length);
    char * vd = VARDATA(res);
    uint64 us = get_current_unix_time_us();

    pg_backend_random(vd+8, 24);

    vd[0] = us>>56;
    vd[1] = us>>48;
    vd[2] = us>>40;
    vd[3] = us>>32;
    vd[4] = us>>24;
    vd[5] = us>>16;
    vd[6] = us>>8;
    vd[7] = us;

    PG_RETURN_BYTEA_P(res);
}

