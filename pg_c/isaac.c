/*
------------------------------------------------------------------------------
isaac64.c: My random number generator for 64-bit machines.
By Bob Jenkins, 1996.  Public Domain.
------------------------------------------------------------------------------
*/
#include "standard.h"
#include "isaac.h"

extern ub8 isaac64_randrsl[ISAAC64_RANDSIZ], isaac64_randcnt;
static ub8 mm[ISAAC64_RANDSIZ];
static ub8 aa = 0, bb = 0, cc = 0;

#define ind(mm, x)  (*(ub8 *)((ub1 *)(mm) + ((x) & ((ISAAC64_RANDSIZ-1)<<3))))
#define rngstep(mix, a, b, mm, m, m2, r, x) \
{ \
  x = *m;  \
  a = (mix) + *(m2++); \
  *(m++) = y = ind(mm,x) + a + b; \
  *(r++) = b = ind(mm,y>>ISAAC64_RANDSIZL) + x; \
}

void isaac64(void) {
    register ub8 a, b, x, y, *m, *m2, *r, *mend;
    m = mm;
    r = isaac64_randrsl;
    a = aa;
    b = bb + (++cc);
    for (m = mm, mend = m2 = m + (ISAAC64_RANDSIZ / 2); m < mend;) {
        rngstep(~(a ^ (a << 21)), a, b, mm, m, m2, r, x);
        rngstep(a ^ (a >> 5), a, b, mm, m, m2, r, x);
        rngstep(a ^ (a << 12), a, b, mm, m, m2, r, x);
        rngstep(a ^ (a >> 33), a, b, mm, m, m2, r, x);
    }
    for (m2 = mm; m2 < mend;) {
        rngstep(~(a ^ (a << 21)), a, b, mm, m, m2, r, x);
        rngstep(a ^ (a >> 5), a, b, mm, m, m2, r, x);
        rngstep(a ^ (a << 12), a, b, mm, m, m2, r, x);
        rngstep(a ^ (a >> 33), a, b, mm, m, m2, r, x);
    }
    bb = b;
    aa = a;
}

#define mix(a, b, c, d, e, f, g, h) \
{ \
   a-=e; f^=h>>9;  h+=a; \
   b-=f; g^=a<<9;  a+=b; \
   c-=g; h^=b>>23; b+=c; \
   d-=h; a^=c<<15; c+=d; \
   e-=a; b^=d>>14; d+=e; \
   f-=b; c^=e<<20; e+=f; \
   g-=c; d^=f>>17; f+=g; \
   h-=d; e^=g<<14; g+=h; \
}

void isaac64_randinit(void) {
    word i;
    ub8 a, b, c, d, e, f, g, h;
    aa = bb = cc = (ub8) 0;
    a = b = c = d = e = f = g = h = 0x9e3779b97f4a7c13LL;  /* the golden ratio */

    for (i = 0; i < 4; ++i)                    /* scramble it */
    {
        mix(a, b, c, d, e, f, g, h);
    }

    for (i = 0; i < ISAAC64_RANDSIZ; i += 8)   /* fill in mm[] with messy stuff */
    {
        a += isaac64_randrsl[i];
        b += isaac64_randrsl[i + 1];
        c += isaac64_randrsl[i + 2];
        d += isaac64_randrsl[i + 3];
        e += isaac64_randrsl[i + 4];
        f += isaac64_randrsl[i + 5];
        g += isaac64_randrsl[i + 6];
        h += isaac64_randrsl[i + 7];
        mix(a, b, c, d, e, f, g, h);
        mm[i] = a;
        mm[i + 1] = b;
        mm[i + 2] = c;
        mm[i + 3] = d;
        mm[i + 4] = e;
        mm[i + 5] = f;
        mm[i + 6] = g;
        mm[i + 7] = h;
    }

    /* do a second pass to make all of the seed affect all of mm */
    for (i = 0; i < ISAAC64_RANDSIZ; i += 8) {
        a += mm[i];
        b += mm[i + 1];
        c += mm[i + 2];
        d += mm[i + 3];
        e += mm[i + 4];
        f += mm[i + 5];
        g += mm[i + 6];
        h += mm[i + 7];
        mix(a, b, c, d, e, f, g, h);
        mm[i] = a;
        mm[i + 1] = b;
        mm[i + 2] = c;
        mm[i + 3] = d;
        mm[i + 4] = e;
        mm[i + 5] = f;
        mm[i + 6] = g;
        mm[i + 7] = h;
    }

    isaac64();          /* fill in the first set of results */
    isaac64_randcnt = ISAAC64_RANDSIZ;    /* prepare to use the first set of results */
}
