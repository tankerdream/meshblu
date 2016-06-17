_ = require 'lodash'

debug = require('debug')('hyga:getToken')
hyGaError = require './models/hyGaError'

getToken = (fromDevice, message, callback=_.noop, dependencies={}) =>

  Device = dependencies.Device ? require('./models/device')
  getDevice = dependencies.getDevice ? require('./getDevice')
  s_securityImpl = dependencies.securityImpl ? require('./s_getSecurityImpl')

  uuid = message.uuid || fromDevice.uuid
  getDevice uuid, (error, targetDevice) =>
    return callback error if error?

    s_securityImpl.canConfigure fromDevice, targetDevice, null, (error, permission) =>
      return callback new hyGaError(401,'Unauthorized') unless permission

      device = new Device {'uuid': uuid}

      device.generateAndStoreTokenInCache (error, sesToken) =>
        return callback error if error?
        callback null, sesToken

module.exports = getToken
