_          = require 'lodash'
async      = require 'async'
debug      = require('debug')('meshblu:SubscriptionGetter')
SimpleAuth = require './simpleAuth'

class SubscriptionGetter
  @SECURITY_MAP:
    broadcast: 'canReceive'
    config: 'canDiscover'

  constructor: (options, dependencies={}) ->
    {@emitterUuid, @type} = options
    {@subscriptions, @devices, @database, @simpleAuth, @Device} = dependencies

    @Device        ?= require './models/device'
    @database      ?= require './database'
    @subscriptions ?= @database.subscriptions
    @devices       ?= @database.devices
    @simpleAuth    ?= new SimpleAuth

  get: (callback) =>
    device = new @Device {uuid: @emitterUuid}, {database: {@devices}}
    device.fetch (error, emitterDevice) =>
      return callback error if error?
      query = emitterUuid: emitterDevice.uuid, type: @type

      @subscriptions.find query, (error, subscriptions) =>
        return callback error if error?
#        取出所有对应uuid的列表
        uuids = _.pluck subscriptions, 'subscriberUuid'

        @_filterAuthorized emitterDevice, uuids, (error, devices) =>
          return callback error if error?
          callback null, _.pluck devices, 'uuid'

#  获取uuid列表对应的所有设备
  _getDevices: (uuids, callback) =>
    async.mapSeries uuids, (uuid, next) =>
      device = new @Device {uuid}, {database: {@devices}}
      device.fetch next
    , callback

# 对设备列表进行过滤,删除不能接受信息的设备,如源设备在目标设备的黑名单中的情况
  _filterAuthorized: (emitterDevice, uuids, callback) =>
    @_getDevices uuids, (error, devices) =>
      return callback error if error?

      async.mapSeries devices, async.apply(@_checkAuthorization, emitterDevice), (error, devices) =>
        callback error, _.compact(devices)

  _checkAuthorization: (emitterDevice, toDevice, callback) =>
    @simpleAuth.canConfigure toDevice, emitterDevice, (error, authorized) =>
      return callback null, toDevice if authorized

      checkAuthorization = @simpleAuth[SubscriptionGetter.SECURITY_MAP[@type]]
      return callback new Error "Unable to check type #{@type}" unless checkAuthorization?

      checkAuthorization toDevice, emitterDevice, (error, authorized) =>
        return callback error if error
        return callback null, toDevice if authorized
        callback()

module.exports = SubscriptionGetter
