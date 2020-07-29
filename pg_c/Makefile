EXTENSION = tuid        # the extensions name
DATA = tuid--0.1.0.sql  # script files to install
REGRESS = tuid_test     # our test script file (without extension)
MODULES = tuid          # our c module file to build

# postgres build stuff
PG_CFLAGS = -O3
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
