(function() {
  var Future, base, defineMemoizedPerInstanceProperty, fibrous, functionWithFiberReturningFuture, futureize, key, objectPrototypeProps, proxyAll, proxyBuilder, synchronize, _i, _j, _len, _len2, _ref, _ref2,
    __slice = Array.prototype.slice;

  require('fibers');

  Future = require('fibers/future');

  functionWithFiberReturningFuture = Function.prototype.future;

  module.exports = fibrous = function(fn) {
    var asyncFn, futureFn;
    futureFn = functionWithFiberReturningFuture.call(fn);
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
    Object.defineProperty(asyncFn, '__fibrousFn__', {
      value: fn,
      enumerable: false
    });
    Object.defineProperty(asyncFn, '__fibrousFutureFn__', {
      value: futureFn,
      enumerable: false
    });
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
      try {
        asyncFn.apply(fnThis, args);
      } catch (e) {
        future["throw"](e);
      }
      return future;
    };
  };

  synchronize = function(asyncFn) {
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (asyncFn.__fibrousFn__) {
        return asyncFn.__fibrousFn__.apply(this === asyncFn && global || this, args);
      }
      return asyncFn.future.apply(this, args).wait();
    };
  };

  objectPrototypeProps = {};

  _ref = Object.getOwnPropertyNames(Object.prototype);
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    key = _ref[_i];
    objectPrototypeProps[key] = true;
  }

  proxyAll = function(src, target, proxyFn) {
    var key, _fn, _j, _len2, _ref2;
    _ref2 = Object.keys(src);
    _fn = function(key) {
      try {
        if (typeof src[key] !== 'function') return;
        if (objectPrototypeProps[key] != null) return;
      } catch (e) {
        return;
      }
      return target[key] = proxyFn(key);
    };
    for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
      key = _ref2[_j];
      _fn(key);
    }
    return target;
  };

  proxyBuilder = function(futureOrSync) {
    return function(that) {
      var func, result;
      result = typeof that === 'function' ? (func = (futureOrSync === 'future' && futureize || synchronize)(that), Object.getPrototypeOf(that) !== Function.prototype ? func.__proto__ = Object.getPrototypeOf(that)[futureOrSync] : void 0, func) : Object.create(Object.getPrototypeOf(that) && Object.getPrototypeOf(that)[futureOrSync] || null);
      result.that = that;
      return proxyAll(that, result, function(key) {
        return function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return this.that[key][futureOrSync].apply(this.that, args);
        };
      });
    };
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

  _ref2 = [Object.prototype, Function.prototype];
  for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
    base = _ref2[_j];
    defineMemoizedPerInstanceProperty(base, 'future', proxyBuilder('future'));
    defineMemoizedPerInstanceProperty(base, 'sync', proxyBuilder('sync'));
  }

  fibrous.wait = function() {
    var futures, getResults, result;
    futures = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    getResults = function(futureOrArray) {
      var i, _k, _len3, _results;
      if (futureOrArray instanceof Future) return futureOrArray.get();
      _results = [];
      for (_k = 0, _len3 = futureOrArray.length; _k < _len3; _k++) {
        i = futureOrArray[_k];
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
