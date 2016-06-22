config = require('./../config')
database = require('./database')
s_securityImpl = require('./s_getSecurityImpl')

getDevice = require './getDevice'
clearCache = require './clearCache'
hyGaError = require './models/hyGaError'

devices = database.devices
rmdevices = database.rmdevices

module.exports = (fromDevice, toDeviceUuid, emitToClient, callback=->) ->
  if !fromDevice or !toDeviceUuid
    return callback hyGaError(400,'Invalid from or to device')

  getDevice toDeviceUuid, (error, toDevice) ->

    return callback(error) if error?

    s_securityImpl.canConfigure fromDevice, toDevice, null, (error, permission) ->
      if error or !permission
        return callback error

#     从mongodb删除设备
      devices.remove { _id: toDeviceUuid }, (error, result) ->

        return callback hyGaError(505, 'Mongo error', error.message) if error?
        return callback hyGaError(404, 'Unregister failed') if result == 0

        toDevice._id = toDevice.uuid
        delete toDevice.uuid

        rmdevices.insert toDevice, ->
          clearCache toDeviceUuid, =>
            callback null