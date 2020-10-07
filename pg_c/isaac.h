/*
------------------------------------------------------------------------------
isaac64.h: definitions for a random number generator
Bob Jenkins, 1996, Public Domain
------------------------------------------------------------------------------
*/
#include "standard.h"

#ifndef ISAAC64
#define ISAAC64

#define ISAAC64_RANDSIZL   (8)
#define ISAAC64_RANDSIZ    (1<<ISAAC64_RANDSIZL)

extern ub8 isaac64_randrsl[ISAAC64_RANDSIZ], isaac64_randcnt;

/*
------------------------------------------------------------------------------
 set the contents of randrsl[0..255] to the seed before calling isaac64_randinit();
------------------------------------------------------------------------------
*/
void isaac64_randinit(void);

void isaac64(void);


/*
------------------------------------------------------------------------------
 Call isaac64_rand() to retrieve a single 64-bit random value
------------------------------------------------------------------------------
*/
#define isaac64_rand() \
   (!isaac64_randcnt-- ? (isaac64(), isaac64_randcnt=ISAAC64_RANDSIZ-1, isaac64_randrsl[isaac64_randcnt]) : \
                 isaac64_randrsl[isaac64_randcnt])

#endif
