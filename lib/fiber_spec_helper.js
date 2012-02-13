(function() {
  var fibrous, jasmineFunction, originalRunner, _fn, _i, _len, _ref,
    __slice = Array.prototype.slice;

  fibrous = require('./fibrous');

  originalRunner = jasmine.Runner.prototype.execute;

  jasmine.Runner.prototype.execute = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return fibrous(originalRunner.bind.apply(originalRunner, [this].concat(__slice.call(args))))(function(err, result) {
      if (err != null) throw err;
    });
  };

  jasmine.Env.prototype.setTimeout = function(f, time) {
    var asyncF;
    asyncF = function(cb) {
      return global.setTimeout(cb, time);
    };
    asyncF.sync();
    return f();
  };

  _ref = ["it", "beforeEach", "afterEach"];
  _fn = function(jasmineFunction) {
    var original;
    original = jasmine.Env.prototype[jasmineFunction];
    return jasmine.Env.prototype[jasmineFunction] = function() {
      var args, spec;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      spec = args.pop();
      if (spec.length === 0) {
        return original.call.apply(original, [this].concat(__slice.call(args), [spec]));
      }
      return original.call.apply(original, [this].concat(__slice.call(args), [function() {
        var asyncSpecFuture, timeout,
          _this = this;
        asyncSpecFuture = spec.future();
        timeout = setTimeout(function() {
          var msg;
          msg = "spec timed out after " + jasmine.DEFAULT_TIMEOUT_INTERVAL + " msec waiting for the asynchronous done callback to be called";
          if (!asyncSpecFuture.isResolved()) {
            return asyncSpecFuture["throw"](new Error(msg));
          }
        }, jasmine.DEFAULT_TIMEOUT_INTERVAL);
        asyncSpecFuture.wait();
        return clearTimeout(timeout);
      }]));
    };
  };
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    jasmineFunction = _ref[_i];
    _fn(jasmineFunction);
  }

}).call(this);
