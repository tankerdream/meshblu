config = require('./../config')
messageIOEmitter = require('./createMessageIOEmitter')()
devices = require('./database').devices
whoAmI = require('./whoAmI')
securityImpl = require('./getSecurityImpl')

s_channels = require('./s_database').s_channels

module.exports = (fromDevice, unregisterUuid, unregisterToken, emitToClient, callback=->) ->
  if !fromDevice or !unregisterUuid
    return callback('invalid from or to device')

  whoAmI unregisterUuid, true, (toDevice) ->
    if toDevice.error
      return callback('invalid device to unregister')

    securityImpl.canConfigure fromDevice, toDevice, { token: unregisterToken }, (error, permission) ->
      if !permission or error
        return callback(
          message: 'unauthorized'
          code: 401)

      if emitToClient
        emitToClient 'unregistered', toDevice, toDevice
      else
        messageIOEmitter toDevice.uuid, 'unregistered', toDevice

      s_channelUuid = toDevice.owner || ''

#     从mongodb删除设备
      devices.remove { uuid: unregisterUuid }, (err, devicedata) ->
        if err or devicedata == 0
          callback
            'message': 'Device not found or token not valid'
            'code': 404
          return

        s_channels.update {uuid:s_channelUuid},{$pull:{devices:unregisterUuid}},(err,data)->
          if err
            callback
              'message':'update failed'
              'code':500
          callback null, uuid: unregisterUuid
