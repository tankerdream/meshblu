getDeviceWithToken = require './getDeviceWithToken'
#根据UUID验证设备有效性，若有效则返回设备
module.exports = (uuid, callback=_.noop, database=null) ->
  deviceFound = (error, data) ->
    delete data.token if data
    callback error, data

  getDeviceWithToken uuid, deviceFound, database
