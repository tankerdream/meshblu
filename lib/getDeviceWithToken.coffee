_ = require 'lodash'
Device = require './models/device'
debug = require('debug')('meshblu:getDeviceWithToken')
#根据UUID返回设备
module.exports = (uuid, callback=_.noop) ->
  debug 'getDeviceWithToken', uuid
  deviceFound = (error, data) ->
    if error || !data
      callback
        error:
          uuid: uuid
          message: 'Device not found'
          code: 404
      return

    callback null, data

  device = new Device uuid: uuid
  device.fetch deviceFound
