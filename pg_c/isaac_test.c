#include "isaac.h"

int main() {
    ub8 i, j;
    for (i = 0; i < ISAAC64_RANDSIZ; ++i) isaac64_randrsl[i] = (ub8) 0;
    isaac64_randinit();

    for (i = 0; i < 2; ++i) {
        isaac64();
        for (j = 0; j < ISAAC64_RANDSIZ; ++j) {
            printf("%016llx ", (ub8) isaac64_randrsl[j]);
            if ((j & 3) == 3)
                printf("\n");
        }
    }

    for (i = 0; i < 10; ++i) {
        printf("%016llx\n", (ub8) isaac64_rand());
    }
}
