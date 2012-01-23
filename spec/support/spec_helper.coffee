fiber_spec_helper = require '../../lib/fiber_spec_helper'

module.exports = spec_helper =
  fail: (msg) ->
    jasmine.getEnv().currentSpec.fail(msg)

