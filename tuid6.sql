-- assumes pgcrypto loaded already

-- version 6 of tuid
-- ignores the uuid version bit because nobody actually cares about them.

create or replace function tuid6()
  returns uuid as
$$
declare
  r bytea;
  ts bigint;
  ret varchar;
begin
  r := gen_random_bytes(10);
  ts := extract(epoch from clock_timestamp() at time zone 'utc') * 1000;

  ret := lpad(to_hex(ts), 12, '0') ||
    lpad(encode(r, 'hex'), 20, '0');

  return ret :: uuid;
end;
$$ language plpgsql;


create or replace function tuid6_from_tz(tz timestamptz)
  returns uuid
  language sql
as
$$
select
  case
    when tz is null
      then null
    else
      (lpad(to_hex((extract(epoch from tz at time zone 'utc') * 1000) :: bigint), 12, '0') || '00000000000000000000')::uuid
    end;
$$;

create or replace function tuid6_tz(tuid uuid)
  returns timestamptz
  language sql
as
$$
with
  t as (
    select tuid::varchar as x
  )
select
  case
    when tuid is null
      then null
    else (
      'x'
          || substr(t.x, 1, 8) -- xxxxxxxx-0000-0000-0000-000000000000
          || substr(t.x, 10, 4) -- 00000000-xxxx-0000-0000-000000000000
      )::bit(48)::bigint * interval '1 millisecond' + timestamptz 'epoch'
    end
from
  t;
$$;

create function tz_to_iso(tz timestamp with time zone) returns character varying
  language sql
  immutable
as
$$
select to_char(tz, 'YYYY-MM-DD"T"HH24:mi:ssZ')
$$;

create function to_b64u(val bytea) returns text
  language sql
  immutable
as
$$
select replace(translate(encode(val, 'base64'), '/+', '_-'), '=', '');
$$;

create function from_b64u(val text) returns bytea
  language sql
  immutable
as
$$
select decode(rpad(translate(val, '_-', '/+'), (ceil(length(val)::float8/4.0)*4)::int, '='), 'base64');
$$;

create function tuid6_to_compact(tuid uuid)
  returns varchar
  language sql
as
$$
select
  case
    when tuid is null
      then null
    else
      to_b64u(decode(replace(tuid::text, '-', ''), 'hex'))
    end;
$$;

create function tuid6_from_compact(compact varchar)
  returns uuid
  language sql
as
$$
select
  case
    when compact is null
      then null
    else
      encode(from_b64u(compact), 'hex')::uuid
    end;
$$;

create function stuid_to_compact(stuid bytea)
  returns varchar
  language sql
as
$$
select
  case
    when stuid is null
      then null
    else
      to_b64u(stuid)
    end;
$$;

create function stuid_from_compact(compact varchar)
  returns bytea
  language sql
as
$$
select
  case
    when compact is null
      then null
    else
      from_b64u(compact)
    end;
$$;

create or replace function stuid()
  returns bytea
  language plpgsql
as
$$
declare
  ct bigint;
  ret bytea;
begin
  ct := extract(epoch from clock_timestamp() at time zone 'utc') * 1000;
  ret := decode(lpad(to_hex(ct), 12, '0'), 'hex') || gen_random_bytes(26);
  return ret;
end;
$$;

create function stuid_tz(stuid bytea)
  returns timestamptz
  language sql
as
$$
select
  case
    when stuid is null
      then null
    else
      (substr(stuid::text, 2, 13))::bit(48)::bigint * interval '1 millisecond' + timestamptz 'epoch'
    end;
$$;

create function tuid_zero()
  returns uuid
  immutable
  language sql as
'select
     ''00000000-0000-0000-0000-000000000000'' :: uuid';

create function max(uuid, uuid)
  returns uuid as
$$
begin
  if $1 is null and $2 is null
  then
    return null;
  end if;

  if $1 is null
  then
    return $2;
  end if;

  if $2 is null
  then
    return $1;
  end if;

  if $1 < $2 then
    return $2;
  end if;

  return $1;
end;
$$ language plpgsql;

create aggregate max (uuid)
  (
  sfunc = max,
  stype = uuid
  );

create function min(uuid, uuid)
  returns uuid as
$$
begin
  if $1 is null and $2 is null
  then
    return null;
  end if;

  if $1 is null
  then
    return $2;
  end if;

  if $2 is null
  then
    return $1;
  end if;

  if $1 > $2 then
    return $2;
  end if;

  return $1;
end;
$$ language plpgsql;

create aggregate min (uuid)
  (
  sfunc = min,
  stype = uuid
  );

