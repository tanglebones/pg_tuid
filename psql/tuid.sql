CREATE OR REPLACE FUNCTION tuid_generate()
  RETURNS UUID AS $$
DECLARE
  ct  BIGINT;
  seq BIGINT;
  nid BIGINT;
  r0  BIGINT;
  r1  BIGINT;
  ax  BIGINT;
  bx  BIGINT;
  cx  BIGINT;
  dx  BIGINT;
  ex  BIGINT;
  fx  BIGINT;
  ret VARCHAR;
BEGIN
  seq := 255;
  nid := 255;
  ct := extract(EPOCH FROM clock_timestamp() AT TIME ZONE 'utc') * 1000000;
  r0 := (random() * 4294967295 :: BIGINT) :: BIGINT;
  r1 := (random() * 4294967295 :: BIGINT) :: BIGINT;

  ax := ct >> 32;
  bx := ct >> 16 & x'FFFF' :: INT;
  cx := x'4000' :: INT | ((ct >> 4) & x'0FFF' :: INT);
  dx := x'8000' :: INT | ((ct & x'F' :: INT) << 10) | (seq << 2) | (nid >> 6);
  ex := ((nid & x'3F' :: INT) << 2) | (r0 & x'3FF' :: INT);
  fx := r1;

  ret :=
    LPAD(TO_HEX(ax),8,'0') ||
    LPAD(TO_HEX(bx),4,'0') ||
    LPAD(TO_HEX(cx),4,'0') ||
    LPAD(TO_HEX(dx),4,'0') ||
    LPAD(TO_HEX(ex),4,'0') ||
    LPAD(TO_HEX(fx),8,'0');

  return ret :: UUID;
END;
$$ LANGUAGE plpgsql;