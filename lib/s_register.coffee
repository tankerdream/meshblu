_             = require 'lodash'
debug         = require('debug')('hyga:s_register')
logEvent      = require './logEvent'

hyGaError     = require('./models/hyGaError');

module.exports = (params={}, callback=_.noop, dependencies={}) =>

# 通过`node-uuid`或`dependencies.uuid`产生的唯一的uuid
# 存储设备等相关信息，若配置`mongodb`，则存储在相应`url`的数据库中；若没有配置，则通过`nedb`存储在文件中。

  s_channelUuid = params.channelUuid
  regToken = params.regToken

  return callback hyGaError(400, 'Invalid channel'),null unless s_channelUuid? && regToken?

  delete params.channelUuid
  delete params.regToken

  debug 's_channel uuid', s_channelUuid

  s_database = dependencies.s_database ? require('./s_database')
  s_authS_Channel = dependencies.s_authS_Channel ? require('./s_authS_Channel')
  register = dependencies.register ? require('./register')

  {s_channels} = s_database

  s_authS_Channel s_channelUuid, regToken, (error, s_channel) =>
    debug 'channel auth error', error
    return callback error,null if error?
    return callback hyGaError(401, 'No permission to add device'),null unless s_channel?

    device = _.cloneDeep params
    device.owner = s_channelUuid

    debug 'device channel', device

    delete device.channel

    register device,(error, newDevice)=>

      debug 'updating device to s_channels',newDevice
      return callback error,null if error?
      return callback hyGaError(500, 'Register failure'),null unless newDevice

      s_channels.update {"uuid":s_channelUuid},{$addToSet:{"devices":newDevice.uuid}},(err,data)->
        if err
          callback hyGaError(500,'update device to channel failed')
        callback null,newDevice