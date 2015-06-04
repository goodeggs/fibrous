// CodeClimate: don't ignore CoffeeScript 1.6.3
(function() {
  var Fiber, Future, base, defineMemoizedPerInstanceProperty, fibrous, functionWithFiberReturningFuture, futureize, proxyAll, proxyBuilder, synchronize, _i, _len, _ref,
    __slice = [].slice;

  Fiber = require('fibers');

  Future = require('fibers/future');

  functionWithFiberReturningFuture = Function.prototype.future;

  module.exports = fibrous = function(fn) {
    var asyncFn, futureFn;
    futureFn = functionWithFiberReturningFuture.call(fn);
    asyncFn = function(cb) {
      var args, callback, future;
      args = 1 <= arguments.length ? Array.prototype.slice.call(arguments, 0) : [];
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
    asyncFn.toString = function() {
      return "fibrous(" + (fn.toString()) + ")";
    };
    return asyncFn;
  };

  futureize = function(asyncFn) {
    return function() {
      var args, e, fnThis, future;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      fnThis = this === asyncFn && global || this;
      if (asyncFn.__fibrousFutureFn__) {
        return asyncFn.__fibrousFutureFn__.apply(fnThis, args);
      }
      future = new Future();
      args.push(future.resolver());
      try {
        asyncFn.apply(fnThis, args);
      } catch (_error) {
        e = _error;
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

  proxyAll = function(src, target, proxyFn) {
    var key, _fn, _i, _len, _ref;
    _ref = Object.keys(src);
    _fn = function(key) {
      if (Object.prototype[key] != null) {
        return;
      }
      if (Object.getOwnPropertyDescriptor(src, key).get != null) {
        return;
      }
      if (typeof src[key] !== 'function') {
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

  proxyBuilder = function(futureOrSync) {
    return function(that) {
      var func, result;
      result = typeof that === 'function' ? (func = (futureOrSync === 'future' && futureize || synchronize)(that), Object.getPrototypeOf(that) !== Function.prototype ? func.__proto__ = Object.getPrototypeOf(that)[futureOrSync] : void 0, func) : Object.create(Object.getPrototypeOf(that) && Object.getPrototypeOf(that)[futureOrSync] || Object.prototype);
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
      set: function(value) {
        delete this[cacheKey];
        return Object.defineProperty(this, propertyName, {
          value: value,
          writable: true,
          configurable: true,
          enumerable: true
        });
      },
      get: function() {
        if (!(Object.prototype.hasOwnProperty.call(this, cacheKey) && this[cacheKey])) {
          Object.defineProperty(this, cacheKey, {
            value: factory(this),
            writable: true,
            configurable: true,
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
    defineMemoizedPerInstanceProperty(base, 'future', proxyBuilder('future'));
    defineMemoizedPerInstanceProperty(base, 'sync', proxyBuilder('sync'));
  }

  fibrous.wait = function() {
    var futures, getResults, result;
    futures = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    getResults = function(futureOrArray) {
      var i, _j, _len1, _results;
      if (futureOrArray instanceof Future) {
        return futureOrArray.get();
      }
      _results = [];
      for (_j = 0, _len1 = futureOrArray.length; _j < _len1; _j++) {
        i = futureOrArray[_j];
        _results.push(getResults(i));
      }
      return _results;
    };
    Future.wait.apply(Future, futures);
    result = getResults(futures);
    if (result.length === 1) {
      result = result[0];
    }
    return result;
  };

  fibrous.middleware = function(req, res, next) {
    return process.nextTick(function() {
      return Fiber(function() {
        var e;
        try {
          return next();
        } catch (_error) {
          e = _error;
          return console.error('Unexpected error bubble up to the top of the fiber:', (e != null ? e.stack : void 0) || e);
        }
      }).run();
    });
  };

  fibrous.run = function(fn, cb) {
    if (cb == null) {
      cb = function(err) {
        if (err != null) {
          throw err;
        }
      };
    }
    return fibrous(fn)(cb);
  };

  fibrous.Future = Future;

}).call(this);
