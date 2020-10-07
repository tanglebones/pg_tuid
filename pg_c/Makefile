MODULE_big = tuid
OBJS = \
	tuid.o \
	isaac.o

EXTENSION = tuid
DATA = tuid--0.3.0.sql
PGFILEDESC = "tuid - time prefix UUIDv4"

# postgres build stuff
PG_CFLAGS = -O3
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
