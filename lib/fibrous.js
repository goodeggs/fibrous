(function() {
  var Future, base, buildFuture, buildSync, defineMemoizedPerInstanceProperty, fibrous, functionWithFiberReturningFuture, futureize, proxyAll, synchronize, _i, _len, _ref,
    __slice = Array.prototype.slice;

  require('fibers');

  Future = require('fibers/future');

  functionWithFiberReturningFuture = Function.prototype.future;

  module.exports = fibrous = function(f) {
    var asyncFn, fiberFn;
    fiberFn = functionWithFiberReturningFuture.call(f);
    asyncFn = function() {
      var args, callback, future;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = args.pop();
      if (!(callback instanceof Function)) {
        throw new Error("Fibrous method expects a callback");
      }
      future = fiberFn.apply(this, args);
      return future.resolve(callback);
    };
    asyncFn.__fibrousFutureFn__ = fiberFn;
    return asyncFn;
  };

  futureize = function(asyncFn) {
    return function() {
      var args, fnThis, future;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      fnThis = this === asyncFn && global || this;
      if (asyncFn.__fibrousFutureFn__) {
        return asyncFn.__fibrousFutureFn__.apply(fnThis, args);
      }
      future = new Future;
      args.push(future.resolver());
      asyncFn.apply(fnThis, args);
      return future;
    };
  };

  synchronize = function(asyncFn) {
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return asyncFn.future.apply(this, args).wait();
    };
  };

  proxyAll = function(src, target, proxyFn) {
    var key, _fn, _i, _len, _ref;
    _ref = Object.keys(src);
    _fn = function(key) {
      try {
        if (typeof src[key] !== 'function') return;
      } catch (e) {
        return;
      }
      return target[key] = proxyFn(key);
    };
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      key = _ref[_i];
      _fn(key);
    }
    return target;
  };

  buildFuture = function(that) {
    var result;
    result = typeof that === 'function' ? futureize(that) : Object.create(Object.getPrototypeOf(that) && Object.getPrototypeOf(that).future || null);
    result.that = that;
    return proxyAll(that, result, function(key) {
      return function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return this.that[key].future.apply(this.that, args);
      };
    });
  };

  buildSync = function(that) {
    var result;
    result = typeof that === 'function' ? synchronize(that) : Object.create(Object.getPrototypeOf(that) && Object.getPrototypeOf(that).sync || null);
    result.that = that;
    return proxyAll(that, result, function(key) {
      return function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return this.that[key].sync.apply(this.that, args);
      };
    });
  };

  defineMemoizedPerInstanceProperty = function(target, propertyName, factory) {
    var cacheKey;
    cacheKey = "__fibrous" + propertyName + "__";
    return Object.defineProperty(target, propertyName, {
      enumerable: false,
      get: function() {
        if (!(this.hasOwnProperty(cacheKey) && this[cacheKey])) {
          Object.defineProperty(this, cacheKey, {
            value: factory(this),
            enumerable: false
          });
        }
        return this[cacheKey];
      }
    });
  };

  _ref = [Object.prototype, Function.prototype];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    base = _ref[_i];
    defineMemoizedPerInstanceProperty(base, 'future', buildFuture);
    defineMemoizedPerInstanceProperty(base, 'sync', buildSync);
  }

  fibrous.wait = function() {
    var futures, getResults, result;
    futures = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    getResults = function(futureOrArray) {
      var i, _j, _len2, _results;
      if (futureOrArray instanceof Future) return futureOrArray.get();
      _results = [];
      for (_j = 0, _len2 = futureOrArray.length; _j < _len2; _j++) {
        i = futureOrArray[_j];
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
