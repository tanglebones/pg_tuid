#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "utils/uuid.h"
#include <time.h>

PG_MODULE_MAGIC;

/* need a lock around these ... */
static unsigned long __last = 0;
static unsigned int __seq = 0;
#define TUID_MAX_SEQ 0xFF

PG_FUNCTION_INFO_V1(generate_tuid);
Datum
generate_tuid(PG_FUNCTION_ARGS)
{
    int16 node_id;

    // ideally node_id would be assigned in a config...
    node_id = PG_GETARG_UINT16(0) & 0xff; // actually UINT8, but that doesn't exist.

    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    unsigned long t_us = (ts.tv_sec * 1000000) + (ts.tv_nsec/1000);
    unsigned long last;
    unsigned int seq;

    // need a lock around this
    if (t_us <= __last) {
        if (__seq > TUID_MAX_SEQ) {
            __seq=0;
            seq=0;
            last=++__last;
        } else {
            seq=++__seq;
            last=__last;
        }
    } else {
        __seq=0;
        seq=0;
        __last = t_us;
        last = t_us;
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
