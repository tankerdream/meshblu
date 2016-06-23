_ = require 'lodash'
Device = require './models/device'

#根据UUID返回设备
module.exports = (uuid, callback=_.noop) ->
  deviceFound = (error, data) ->
    callback error, data

  device = new Device uuid: uuid
  device.fetch deviceFound
