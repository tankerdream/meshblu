_             = require 'lodash'
debug         = require('debug')('meshblu:register')
generateToken = require './generateToken'
logEvent      = require './logEvent'

module.exports = (device={}, callback=_.noop, dependencies={}) ->

# 通过`node-uuid`或`dependencies.uuid`产生的唯一的uuid
# 存储设备等相关信息，若配置`mongodb`，则存储在相应`url`的数据库中；若没有配置，则通过`nedb`存储在文件中。
  uuid         = dependencies.uuid || require 'node-uuid'
  database     = dependencies.database ? require './database'
  oldUpdateDevice = dependencies.oldUpdateDevice ? require './oldUpdateDevice'
  {devices}    = database

  device = _.cloneDeep device

  newDevice =
    uuid: uuid.v4()
    online: false

  debug "registering", device

  devices.insert newDevice, (error) =>
    debug 'inserted', error
    return callback new Error('Device not registered') if error?
#    insert操作只是将device的uuid和online加入devices表中
    device.token ?= generateToken()

#    将device中的其他参数加入到devices表中
    debug 'about to update device', device
    oldUpdateDevice newDevice.uuid, device, (error, savedDevice) =>
      debug 'oldUpdateDevice', error
      return callback new Error('Device not updated') if error?
      debug 'updated', error
      debug 'updated device', savedDevice

#      savedDevice指已经保存了的设备
      logEvent 400, savedDevice
      savedDevice.token = device.token
#      保存设备成功则调用上层回调函数(error,data)
      callback null, savedDevice
