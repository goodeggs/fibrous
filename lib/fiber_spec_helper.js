(function() {
  var fiber_spec_helper;
  var __slice = Array.prototype.slice;

  require('fibers');

  module.exports = fiber_spec_helper = {
    addFiberVariants: function(context) {
      var jasmineFunction, _i, _len, _ref, _results;
      _ref = ["it", "xit", "beforeEach", "afterEach"];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        jasmineFunction = _ref[_i];
        _results.push((function(jasmineFunction) {
          var original, variant;
          variant = jasmineFunction + 'Fiber';
          if (context[variant]) return;
          original = context[jasmineFunction];
          return context[variant] = function() {
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
        })(jasmineFunction));
      }
      return _results;
    }
  };

}).call(this);
