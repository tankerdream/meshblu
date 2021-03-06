debug = require('debug')('meshblu:resetToken')

hyGaError = require('./models/hyGaError')

resetToken  = (fromDevice, uuid, emitToClient, callback=(->), {securityImpl, getDevice, Device}={}) ->
  securityImpl ?= require './getSecurityImpl'
  getDevice ?= require './getDevice'
  Device ?= require './models/device'

#TODO 清除meshblu-token-cache,防止就token访问依然有效

  getDevice uuid, (error, gotDevice) ->
    debug 'error',error
    return callback hyGaError(401,'Invalid device') if error?

    securityImpl.canConfigure fromDevice, gotDevice, (error, permission) =>
      return callback "unauthorized" unless permission

      device = new Device uuid: uuid
      device.resetToken (error, token) =>
        return callback hyGaError(401,'Error updating device') if error?
        emitToClient 'notReady', fromDevice, {}
        debug 'token',token
        return callback null, token

module.exports = resetToken
