_             = require 'lodash'
debug         = require('debug')('meshblu:s_register')
logEvent      = require './logEvent'

hyGaError     = require('./models/hyGaError');

module.exports = (s_channel={},device={}, callback=_.noop, dependencies={}) =>

# 通过`node-uuid`或`dependencies.uuid`产生的唯一的uuid
# 存储设备等相关信息，若配置`mongodb`，则存储在相应`url`的数据库中；若没有配置，则通过`nedb`存储在文件中。

  uuid  = s_channel.uuid
  token = s_channel.token

  debug 's_channel uuid', uuid

  return callback hyGaErrorError(400, 'Invalid channel'),null unless uuid? && token?

  s_database = dependencies.s_database ? require('./s_database')
  s_authS_Channel = dependencies.s_authS_Channel ? require('./s_authS_Channel')
  register = dependencies.register ? require('./register')

  {s_channels} = s_database

  s_authS_Channel uuid, token, (error, s_channel) =>
    return callback error,null if error?
    return callback hyGaError(401, 'No permission to add device'),null unless s_channel?

    device = _.cloneDeep device
    device.owner = uuid

    debug 'device channel', device

    delete device.channel

    register device,(error, newDevice)=>

      debug 'updating device to s_channels',newDevice
      return callback error,null if error?
      return callback hyGaError(500, 'Register failure'),null unless newDevice

      s_channels.update {"uuid":s_channel.uuid},{$addToSet:{"devices":newDevice.uuid}},(err,data)->
        if err
          callback hyGaError(500,'update device to channel failed')
        callback null,newDevice