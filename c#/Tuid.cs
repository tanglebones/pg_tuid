using System;

namespace Tuid
{
    public sealed class Generator
    {
        private readonly object _lock = new object();
        private ulong _last = 0;
        private ulong _seq = 0;
        private readonly ulong _nid = 0;
        private readonly Func<ulong> _clock;
        private readonly Func<ulong> _random;

        public Generator(ulong nid = 255, Func<ulong> clock = null, Func<ulong> random = null)
        {
            _clock = clock;
            _random = random;

            if (clock == null)
                _clock = DefaultClock;
            if (random == null)
                _random = DefaultRandom;
            _nid = nid;
            if (_nid > 255) {
              _nid = _random() & 0xff;
            }
        }

        private static readonly DateTime Epoch =
            new DateTime(1970, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc).ToUniversalTime();

        private static ulong DefaultClock()
        {
            return (ulong) (DateTime.UtcNow.Subtract(Epoch).TotalMilliseconds * 1000F);
        }

        private static readonly Random Random = new Random();

        private static ulong DefaultRandom()
        {
            return
                ((ulong) Random.Next() << 48) ^
                ((ulong) Random.Next() << 32) ^
                ((ulong) Random.Next() << 16) ^
                ((ulong) Random.Next());
        }

        public string Generate()
        {
            var us = _clock();
            var rand1 = _random();
            lock (_lock)
            {
                if (us <= _last)
                {
                    if (_seq >= 0xff)
                    {
                        ++_last;
                        _seq = 0;
                    }
                    else
                    {
                        ++_seq;
                    }
                }
                else
                {
                    _seq = (rand1 >> 12) & 0xff;
                    _last = us;
                }
            
                var a = _last >> 32;
                var b = (_last >> 16) & 0xffff;
                var c = 0x4000 | ((_last >> 4) & 0x0fff);
                var d = 0x8000 | ((_last & 0xf) << 10) | (_seq << 2) | (_nodeId >> 6);
                var e = ((_nid & 0x3f) << 10) | (rand1 & 0x3ff);
                var f = rand1>>32;
                return $"{a:x08}-{b:x04}-{c:x04}-{d:x04}-{e:x04}{f:x08}";
            }
        }
    }
}
