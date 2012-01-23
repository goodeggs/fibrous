(function() {
  var Future, fibrous;
  var __slice = Array.prototype.slice;

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

  fibrous.wrap = function(obj) {
    var attr, fn, key, _i, _len, _ref;
    if (obj.__fibrouswrapped__) return obj;
    _ref = ['sync', 'future'];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      attr = _ref[_i];
      if (obj[attr] != null) {
        throw new Error("the object to wrap already has a ." + attr + " attribute [" + obj[attr] + "]");
      }
    }
    obj.__fibrouswrapped__ = true;
    obj.future = {};
    obj.sync = {};
    for (key in obj) {
      fn = obj[key];
      if (typeof fn === 'function') {
        (function(key) {
          obj.future[key] = function() {
            var args, future;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            fn = obj[key];
            if (fn.__fibrousFutureFn__) {
              return fn.__fibrousFutureFn__.apply(obj, args);
            }
            future = new Future;
            args.push(future.resolver());
            fn.apply(obj, args);
            return future;
          };
          return obj.sync[key] = function() {
            var args, _ref2;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            return (_ref2 = obj.future)[key].apply(_ref2, args).wait();
          };
        })(key);
      }
    }
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
