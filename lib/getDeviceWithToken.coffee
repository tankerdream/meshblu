_ = require 'lodash'
Device = require './models/device'
debug = require('debug')('meshblu:getDeviceWithToken')

hyGaError = require('./models/hyGaError');

#根据UUID返回设备
module.exports = (uuid, callback=_.noop) ->
  debug 'getDeviceWithToken', uuid
  deviceFound = (error, data) ->
    debug 'error', error
    if error || !data
      callback hyGaError(404,'Device not found',{uuid: uuid})
      return
    debug 'data',data
    callback null, data

  device = new Device uuid: uuid
  device.fetch deviceFound
