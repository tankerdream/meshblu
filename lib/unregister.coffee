config = require('./../config')
messageIOEmitter = require('./createMessageIOEmitter')()
database = require('./database')
whoAmI = require('./whoAmI')
s_securityImpl = require('./s_getSecurityImpl')

clearCache = require './clearCache'
hyGaError = require('./models/hyGaError');

devices = database.devices
rmdevices = database.rmdevices

module.exports = (fromDevice, unregisterUuid, emitToClient, callback=->) ->
  if !fromDevice or !unregisterUuid
    return callback hyGaError(400,'Invalid from or to device')

  whoAmI unregisterUuid, true, (toDevice) ->
    if toDevice.error
      return callback hyGaError(404,'Invalid device to unregister')

    s_securityImpl.canConfigure fromDevice, toDevice, (error, permission) ->
      if !permission or error
        return callback hyGaError(401,'Unauthorized')

#        TODO 谁订阅了这些消息?
      if emitToClient
        emitToClient 'unregistered', toDevice, toDevice
      else
        messageIOEmitter toDevice.uuid, 'unregistered', toDevice

#     从mongodb删除设备
      devices.remove { uuid: unregisterUuid }, (err, devicedata) ->
        if err or devicedata == 0
          return callback hyGaError(404,'Device not found or token not valid')
        rmdevices.insert toDevice, ->
          clearCache unregisterUuid, =>
            callback null, uuid: unregisterUuid

