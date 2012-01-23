(function() {
  var fiber_spec_helper, jasmineFunction, _fn, _i, _len, _ref;
  var __slice = Array.prototype.slice;

  require('fibers');

  module.exports = fiber_spec_helper = {};

  _ref = ["it", "beforeEach", "afterEach"];
  _fn = function(jasmineFunction) {
    var original;
    original = global[jasmineFunction];
    return global[jasmineFunction + 'Fiber'] = function() {
      var args, spec;
      var _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      spec = args.pop();
      return original.apply(null, __slice.call(args).concat([function() {
        var done;
        done = false;
        runs(function() {
          var future;
          future = spec.future().apply(this);
          return future.resolve(function(err, result) {
            done = true;
            if (err != null) return jasmine.getEnv().currentSpec.fail(err);
          });
        });
        return waitsFor(function() {
          return done === true;
        }, "fiber to complete");
      }]));
    };
  };
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    jasmineFunction = _ref[_i];
    _fn(jasmineFunction);
  }

}).call(this);
