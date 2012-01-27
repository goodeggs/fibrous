(function() {
  var Future, fibrous,
    __slice = Array.prototype.slice;

  require('fibers');

  Future = require('fibers/future');

  module.exports = fibrous = function(f) {
    var asyncFn, futureFn;
    futureFn = f.future();
    asyncFn = function() {
      var args, callback, future;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = args.pop();
      if (!(callback instanceof Function)) {
        throw new Error("Fibrous method expects a callback");
      }
      future = futureFn.apply(this, args);
      return future.resolve(callback);
    };
    asyncFn.__fibrousFutureFn__ = futureFn;
    return asyncFn;
  };

  fibrous.wrap = function(obj, options) {
    var FutureMethods, SyncMethods, key, _fn;
    if (options == null) options = {};
    if (obj.__fibrouswrapped__) return obj;
    if (obj.sync != null) {
      throw new Error("the object to wrap already has a .sync attribute [" + obj.sync + "]");
    }
    if ((obj.future != null) && obj.future !== Function.prototype.future) {
      throw new Error("the object to wrap already has a .future attribute [" + obj.future + "]");
    }
    obj.__fibrouswrapped__ = true;
    FutureMethods = (function() {

      function FutureMethods(that) {
        this.that = that;
      }

      return FutureMethods;

    })();
    SyncMethods = (function() {

      function SyncMethods(that) {
        this.that = that;
      }

      return SyncMethods;

    })();
    _fn = function(key) {
      try {
        if (typeof obj[key] !== 'function') return;
      } catch (e) {
        return;
      }
      FutureMethods.prototype[key] = function() {
        var args, fn, future;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        fn = this.that[key];
        if (fn.__fibrousFutureFn__) {
          return fn.__fibrousFutureFn__.apply(this.that, args);
        }
        future = new Future;
        args.push(future.resolver());
        fn.apply(this.that, args);
        return future;
      };
      return SyncMethods.prototype[key] = function() {
        var args, _ref;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return (_ref = this.that.future)[key].apply(_ref, args).wait();
      };
    };
    for (key in obj) {
      _fn(key);
    }
    Object.defineProperty(obj, 'future', {
      get: function() {
        var _ref;
        return (_ref = this.__fibrousfuture__) != null ? _ref : this.__fibrousfuture__ = new FutureMethods(this);
      }
    });
    Object.defineProperty(obj, 'sync', {
      get: function() {
        var _ref;
        return (_ref = this.__fibroussync__) != null ? _ref : this.__fibroussync__ = new SyncMethods(this);
      }
    });
    if (options.prototype && obj.prototype) fibrous.wrap(obj.prototype);
    return obj;
  };

  fibrous.require = function(modName) {
    var result;
    result = require(modName);
    fibrous.wrap(result);
    return result;
  };

  fibrous.wait = function() {
    var futures, getResults, result;
    futures = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    getResults = function(futureOrArray) {
      var i, _i, _len, _results;
      if (futureOrArray instanceof Future) return futureOrArray.get();
      _results = [];
      for (_i = 0, _len = futureOrArray.length; _i < _len; _i++) {
        i = futureOrArray[_i];
        _results.push(getResults(i));
      }
      return _results;
    };
    Future.wait.apply(Future, futures);
    result = getResults(futures);
    if (result.length === 1) result = result[0];
    return result;
  };

  fibrous.middleware = function(req, res, next) {
    return process.nextTick(function() {
      return Fiber(function() {
        try {
          return next();
        } catch (e) {
          return console.error('Unexpected error bubble up to the top of the fiber:', (e != null ? e.stack : void 0) || e);
        }
      }).run();
    });
  };

  fibrous.specHelper = require('./fiber_spec_helper');

}).call(this);
