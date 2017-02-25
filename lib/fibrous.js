// CodeClimate: don't ignore CoffeeScript 1.10.0
(function() {
  var Fiber, Future, base, defineMemoizedPerInstanceProperty, fibrous, functionWithFiberReturningFuture, futureize, j, len, proxyAll, proxyBuilder, ref, skipProps, synchronize,
    slice = [].slice;

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
      var args, e, error, fnThis, future;
      args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      fnThis = this === asyncFn && global || this;
      if (asyncFn.__fibrousFutureFn__) {
        return asyncFn.__fibrousFutureFn__.apply(fnThis, args);
      }
      future = new Future();
      args.push(future.resolver());
      try {
        asyncFn.apply(fnThis, args);
      } catch (error) {
        e = error;
        future["throw"](e);
      }
      return future;
    };
  };

  synchronize = function(asyncFn) {
    return function() {
      var args;
      args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      if (asyncFn.__fibrousFn__) {
        return asyncFn.__fibrousFn__.apply(this === asyncFn && global || this, args);
      }
      return asyncFn.future.apply(this, args).wait();
    };
  };

  skipProps = {
    constructor: true,
    sync: true,
    future: true
  };

  proxyAll = function(src, target, proxyFn) {
    var fn1, j, key, len, ref;
    ref = Object.getOwnPropertyNames(src);
    fn1 = function(key) {
      var propertyDescriptor;
      if (skipProps[key]) {
        return;
      }
      if (Object.prototype[key] != null) {
        return;
      }
      propertyDescriptor = Object.getOwnPropertyDescriptor(src, key);
      if (propertyDescriptor.get != null) {
        return;
      }
      if (typeof src[key] !== 'function') {
        return;
      }
      return Object.defineProperty(target, key, {
        configurable: propertyDescriptor.configurable,
        enumerable: propertyDescriptor.enumerable,
        writable: propertyDescriptor.writable,
        value: proxyFn(key)
      });
    };
    for (j = 0, len = ref.length; j < len; j++) {
      key = ref[j];
      fn1(key);
    }
    return target;
  };

  proxyBuilder = function(futureOrSync) {
    return function(that) {
      var func, ize, proto, result, thatArrayReturn;
      result = typeof that === 'function' ? (ize = futureOrSync === 'future' && futureize || synchronize, func = ize(that), Object.getPrototypeOf(that) !== Function.prototype ? proto = Object.getPrototypeOf(that)[futureOrSync] : void 0, func.__proto__ = proto, thatArrayReturn = (function(f, this_) {
        return function() {
          var args, callback, _i;
          args = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), callback = arguments[_i++];
          args.push(function() {
            var cbArgs, err;
            err = arguments[0], cbArgs = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
            return callback(err, cbArgs);
          });
          return f.apply(this_, args);
        };
      })(that, that), func.Array = ize(thatArrayReturn), func.Array.__proto__ = proto, func) : Object.create(Object.getPrototypeOf(that) && Object.getPrototypeOf(that)[futureOrSync] || Object.prototype);
      result.that = that;
      return proxyAll(that, result, function(key) {
        return function() {
          var args;
          args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
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

  ref = [Object.prototype, Function.prototype];
  for (j = 0, len = ref.length; j < len; j++) {
    base = ref[j];
    defineMemoizedPerInstanceProperty(base, 'future', proxyBuilder('future'));
    defineMemoizedPerInstanceProperty(base, 'sync', proxyBuilder('sync'));
  }

  fibrous.wait = function() {
    var futures, getResults, result;
    futures = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    getResults = function(futureOrArray) {
      var i, k, len1, results;
      if (futureOrArray instanceof Future) {
        return futureOrArray.get();
      }
      results = [];
      for (k = 0, len1 = futureOrArray.length; k < len1; k++) {
        i = futureOrArray[k];
        results.push(getResults(i));
      }
      return results;
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
        var e, error;
        try {
          return next();
        } catch (error) {
          e = error;
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
