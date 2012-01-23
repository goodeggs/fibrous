(function() {
  var Future, fibrous;
  var __slice = Array.prototype.slice;

  require('fibers');

  Future = require('fibers/future');

  module.exports = fibrous = function(f) {};

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
            future = new Future;
            args.push(future.resolver());
            obj[key].apply(obj, args);
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

}).call(this);
