_ = require 'lodash'

module.exports = (sendMessage, fromDevice, toDeviceUuid, params, callback=_.noop, dependencies={}) ->
  securityImpl = dependencies.securityImpl ? require './getSecurityImpl'
  getDevice = dependencies.getDevice ? require './getDevice'
  dataDB = dependencies.dataDB ? require('./database').data
  logEvent = dependencies.logEvent ? require './logEvent'
  moment = dependencies.moment ? require 'moment'

  data = {}
  data.uuid = toDeviceUuid
  data.val = params?.val
  key = params?.key

  return callback Error('Invalid data') unless data.uuid && data.val && key

  data.timestamp ?= moment().toISOString()
  data.timestamp = moment(data.timestamp).toISOString()

  getDevice toDeviceUuid, (error, toDevice) =>
    return callback new Error(error.error.message) if error?
    securityImpl.canSend fromDevice, toDevice, params, (error, permission) =>
      return callback error if error?
      return callback new Error('Owner has no permission to save data') unless permission

      dataDB.update {'userUuid':toDevice.owner},{$push:{"#{key}":data}},(error,saved)->
        return callback error if error?

        callback null,saved
