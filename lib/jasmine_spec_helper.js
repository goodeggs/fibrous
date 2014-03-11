// CodeClimate: don't ignore CoffeeScript 1.6.3
(function() {
  var fibrous, jasmineFunction, _fn, _i, _len, _ref, _ref1,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  fibrous = require('./fibrous');

  jasmine.AsyncBlock = (function(_super) {
    __extends(AsyncBlock, _super);

    function AsyncBlock() {
      _ref = AsyncBlock.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    AsyncBlock.prototype.execute = function(onComplete) {
      var complete, completed, timeout,
        _this = this;
      completed = false;
      complete = function(err) {
        if (completed) {
          return console.error("A completed async spec \"" + (_this.spec.getFullName()) + "\" has completed again with", (err != null ? err.stack : void 0) || err);
        } else {
          completed = true;
          clearTimeout(timeout);
          if (err != null) {
            _this.spec.fail(err);
          }
          return process.nextTick(onComplete);
        }
      };
      timeout = setTimeout(function() {
        return complete(new Error("spec timed out after " + jasmine.DEFAULT_TIMEOUT_INTERVAL + " msec"));
      }, jasmine.DEFAULT_TIMEOUT_INTERVAL);
      return this.func.call(this.spec, complete);
    };

    return AsyncBlock;

  })(jasmine.Block);

  _ref1 = ["it", "beforeEach", "afterEach"];
  _fn = function(jasmineFunction) {
    var original;
    original = jasmine.Env.prototype[jasmineFunction];
    return jasmine.Env.prototype[jasmineFunction] = function() {
      var args, func;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      while (typeof func !== 'function') {
        func = args.pop();
      }
      return original.call.apply(original, [this].concat(__slice.call(args), [function() {
        var asyncBlock, asyncFunc;
        asyncFunc = (func.length === 1) && func || fibrous(func);
        asyncBlock = new jasmine.AsyncBlock(this.env, asyncFunc, this);
        return this.addToQueue(asyncBlock);
      }]));
    };
  };
  for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
    jasmineFunction = _ref1[_i];
    _fn(jasmineFunction);
  }

}).call(this);
