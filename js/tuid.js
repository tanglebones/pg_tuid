var tuid = function() {
  var pad = function(p,s) {
    var x = p + s;
    return x.substr(x.length-p.length);
  };

  var rhc = function(p) {
    var x = (Math.random()*(16**p.length))|0;
    return pad(p,x.toString(16));
  };

  var ts = pad("0000000000000000",(Date.now()*1000).toString(16));
  var x = parseInt(ts.substr(15,1),16);
  ts = ts.substr(0,8)+'-'+ts.substr(8,4)
    +'-4'+ts.substr(12,3)
    +'-'+(8+(x>>2)).toString(16)
    +(((x&3)<<6)|3).toString(16)
    +rhc("00")
    +'-'
    +rhc("0000")+rhc("0000")+rhc("0000");
  return ts;
};

