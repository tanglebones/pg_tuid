#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include "postgres.h"
#include "utils/builtins.h"
#include "utils/uuid.h"
#include "isaac.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

#define TUID_MAX_SEQ 0xFF

PG_FUNCTION_INFO_V1(tuid_generate);
PG_FUNCTION_INFO_V1(stuid_generate);

void _PG_init(void);

void _PG_fini(void);

unsigned int random_unsigned_int(void);


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
static uint64 get_current_unix_time_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64 sec = (uint64) tv.tv_sec;
    uint64 usec = (uint64) tv.tv_usec;
    return (sec * 1000000) + usec;
}

#endif


void init_rand(void);

void init_rand(void) {
    uint64 *seed = (uint64 *) isaac64_randrsl;
    for (uint64 i = 0; i < ISAAC64_RANDSIZL; ++i) {
        seed[i] = get_current_unix_time_us() ^ (i << 32) ^ MyProcPid;
    }
    isaac64_randinit();
}

void _PG_init(void) {
    elog(LOG, "pg_tuid init");
    init_rand();
}

void _PG_fini(void) {
}

Datum
tuid_generate(PG_FUNCTION_ARGS) {
    uint8 *buffer = (uint8 *) palloc(UUID_LEN);
    uint64 t_us = get_current_unix_time_us();
    uint64 r = isaac64_rand();

    /*
      01234567-0123-0123-(0000)(1111)23-0123456789ab\0
      TTTTTTTT-TTTT-1TTT-(10TT)(TTrr)rr-rrrrRRRRRRRR\0

      The 4 and 10 hard coded into the above are the version bits for UUID4
    */

    /*
      64 bits of time
      6 bits of UUID version markers
      58 bits of random
    */

    buffer[0] = (t_us >> 56);
    buffer[1] = (t_us >> 48);
    buffer[2] = (t_us >> 40);
    buffer[3] = (t_us >> 32);

    buffer[4] = (t_us >> 24);
    buffer[5] = (t_us >> 16);

    buffer[6] = (0x40 | ((t_us >> 12)&0xf));
    buffer[7] = (t_us >> 4);

    ((uint64 *) buffer)[1] = r;

    buffer[8] = (0x80 | ((t_us & 0xf) << 10) | (r & 0x3));
    buffer[9] = (r >> 2);

    PG_RETURN_UUID_P((pg_uuid_t *) buffer);
}

Datum
stuid_generate(PG_FUNCTION_ARGS) {
    bytea *res;
    int length = VARHDRSZ + 32;
    res = palloc(length);
    SET_VARSIZE(res, length);
    char *vd = VARDATA(res);

    uint64 us = get_current_unix_time_us();

    vd[0] = us >> 56;
    vd[1] = us >> 48;
    vd[2] = us >> 40;
    vd[3] = us >> 32;
    vd[4] = us >> 24;
    vd[5] = us >> 16;
    vd[6] = us >> 8;
    vd[7] = us;

    ((uint64 *) vd)[1] = isaac64_rand();
    ((uint64 *) vd)[2] = isaac64_rand();
    ((uint64 *) vd)[3] = isaac64_rand();

    PG_RETURN_BYTEA_P(res);
}

