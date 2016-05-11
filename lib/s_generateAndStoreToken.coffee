_ = require 'lodash'

debug = require('debug')('hyga:getToken')
hyGaError = require './models/hyGaError'

getToken = (ownerDevice, message, callback=_.noop, dependencies={}) =>

  Device = dependencies.Device ? require('./models/device')
  getDevice = dependencies.getDevice ? require('./getDevice')
  s_securityImpl = dependencies.securityImpl ? require('./s_getSecurityImpl')
  {uuid, tag} = message

  getDevice uuid, (error, targetDevice) =>
    return callback error if error?

    s_securityImpl.canConfigure ownerDevice, targetDevice, (error, permission) =>
      return callback new hyGaError(401,'Unauthorized') unless permission

      device = new Device {uuid}
#      token = device.generateToken()

#      storeTokenOptions = {token}
#      TODO tag的作用?
#      storeTokenOptions.tag = tag if tag?
#      debug 'before store'

      device.generateAndStoreTokenInCache (error, token) =>
        return callback error if error?
        callback null, {
          uuid: uuid
          sesToken: token
        }

module.exports = getToken
