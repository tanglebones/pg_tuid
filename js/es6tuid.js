/* eslint no-bitwise: ["error", { "allow": ["&","|"] }] */

export default function () {
  const pad = function pad(p, s) {
    const x = p + s;
    return x.substr(x.length - p.length);
  };

  const rhc = function rhc(p) {
    const x = Math.random() * (16 ** p.length) | 0;
    return pad(p, x.toString(16));
  };

  const ts = pad('0000000000000000', (Date.now() * 1000).toString(16));
  const x = parseInt(ts.substr(15, 1), 16);
  return `${ts.substr(0, 8)}-${ts.substr(8, 4)}-4${ts.substr(12, 3)}-${(8 + (x / 4)).toString(16)}${(((x & 3) * 64) | 3).toString(16)}${rhc('00')}-${rhc('0000')}${rhc('0000')}${rhc('0000')}`;
}
