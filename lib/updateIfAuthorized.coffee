_ = require 'lodash'

updateIfAuthorized = (fromDevice, query, params, options, callback, dependencies={}) ->
  s_securityImpl = dependencies.securityImpl ? require('./s_getSecurityImpl')
  Device = dependencies.Device ? require('./models/device')

  device = new Device uuid: query.uuid
  device.fetch (error, toDevice) =>
    s_securityImpl.canConfigure fromDevice, toDevice, (error, permission) =>
      return callback error if error?
      return callback new Error('Device does not have sufficient permissions for update') unless permission

      device.update params, options, (error) =>
        return callback error if error?
        callback()

#Figure it out. I dare you!
module.exports = module.exports = (fromDevice, query, params, rest...) ->
  [callback, dependencies] = rest
  [options, callback, dependencies] = rest if _.isPlainObject callback
  options ?= {}
  dependencies ?={}

  updateIfAuthorized fromDevice, query, params, options, callback, dependencies
