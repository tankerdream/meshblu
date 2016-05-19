debug = require('debug')('hyga:resetToken')

hyGaError = require('./models/hyGaError')

resetToken  = (fromDevice, uuid, callback=(->), {s_securityImpl, getDevice, Device}={}) ->
  s_securityImpl ?= require './s_getSecurityImpl'
  getDevice ?= require './getDevice'
  Device ?= require './models/device'

#TODO 清除meshblu-token-cache,防止就token访问依然有效

  debug 'resetToken'

  getDevice uuid, (error, gotDevice) ->
    debug 'error',error
    return callback hyGaError(401,'Invalid device') if error?

    s_securityImpl.canConfigure fromDevice, gotDevice, (error, permission) =>
      return callback hyGaError(400, "Unauthorized") unless permission

      device = new Device uuid: uuid
      device.resetToken (error, token) =>
        return callback hyGaError(401,'Error updating device') if error?
        debug 'token',token
        return callback null, token

module.exports = resetToken
