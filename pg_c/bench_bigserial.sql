INSERT INTO b_bigserial (n) SELECT n FROM generate_series(1, 100000) s(n);
