async = require 'async'
bcrypt = require "bcrypt"
_ = require "lodash"
UUIDAliasResolver = require '../src/uuid-alias-resolver'

debug = require("debug")("hyga:s_simpleAuth")

#设备各种属性的检测
class SimpleAuth

  constructor: (@dependencies={}) ->
    {aliasServerUri, @authDevice} = @dependencies
    @authDevice ?= require './authDevice'
    @uuidAliasResolver = new UUIDAliasResolver {}, {@redis, aliasServerUri}

  asyncCallback: (error, result, callback) =>
    _.defer callback, error, result

# 判断源设备是否在目的设备的白名单或黑名单中
  _checkLists: (fromDevice, toDevice, whitelist, blacklist, openByDefault, callback) =>
    @_resolveList whitelist, (error, resolvedWhitelist) =>
      return callback error if error?


      @_resolveList blacklist, (error, resolvedBlacklist) =>
        return callback error if error?

        toDeviceAlias = toDevice.uuid
        fromDeviceAlias = fromDevice.uuid

        @uuidAliasResolver.resolve toDeviceAlias, (error, toDeviceUuid) =>
          return callback error if error?

          @uuidAliasResolver.resolve fromDeviceAlias, (error, fromDeviceUuid) =>
            return callback error if error?

            return callback null, true if toDeviceUuid == fromDeviceUuid

            return callback null, true if _.contains resolvedWhitelist, '*'

#            console.log 'white' + resolvedWhitelist + '\nfrom:' + fromDeviceUuid

            return callback null, _.contains(resolvedWhitelist, fromDeviceUuid) if resolvedWhitelist?

            return callback null, !_.contains(resolvedBlacklist, fromDeviceUuid) if resolvedBlacklist?

            callback null, openByDefault

  _s_checkLists: (fromDevice, toDevice, whitelist, blacklist, openByDefault, callback) =>

    @_resolveList blacklist, (error, resolvedBlacklist) =>
      return callback error if error?

      toDeviceAlias = toDevice.uuid
      fromDeviceAlias = fromDevice.uuid

      @uuidAliasResolver.resolve toDeviceAlias, (error, toDeviceUuid) =>
        return callback error if error?

        @uuidAliasResolver.resolve fromDeviceAlias, (error, fromDeviceUuid) =>
          return callback error if error?

          return callback null, true if toDeviceUuid == fromDeviceUuid

          return callback null, false if resolvedBlacklist? && _.contains(resolvedBlacklist, fromDeviceUuid)

          return callback null, true if openByDefault

          @_resolveList whitelist, (error, resolvedWhitelist) =>

            return callback error if error?
            #console.log 'white' + resolvedWhitelist + '\nfrom:' + fromDeviceUuid
            return callback null, _.contains(resolvedWhitelist, fromDeviceUuid) if resolvedWhitelist?

            callback null, openByDefault

#    判断源设备是否可以配置目标设备
  canConfigure: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    @_checkLists fromDevice, toDevice, toDevice.configureWhitelist, toDevice.configureBlacklist, false, (error, inList) =>
      return callback error if error?
      return callback null, true if inList

      return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid

      return @asyncCallback(null, true, callback) if toDevice.owner == fromDevice.uuid if toDevice.owner?

      if message?.token
        return @authDevice(
          toDevice.uuid
          message.token
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
        )

      @asyncCallback(null, false, callback)

  canConfigureAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
      )

    configureAsWhitelist = _.cloneDeep toDevice.configureAsWhitelist
    unless configureAsWhitelist
      configureAsWhitelist = []
      configureAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, configureAsWhitelist, toDevice.configureAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canDiscover: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    @_checkLists fromDevice, toDevice, toDevice.discoverWhitelist, toDevice.discoverBlacklist, true, (error, inList) =>
      return callback error if error?
      return callback null, true if inList

      if message?.token
        return @authDevice(
          toDevice.uuid
          message.token
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
        )

      defaultAuth = @_check_authority(fromDevice,toDevice)

      debug 'canDiscover defaultAuth', defaultAuth

      @_s_checkLists fromDevice, toDevice, toDevice.sendWhitelist, toDevice.sendBlacklist, defaultAuth, (error, inList) =>
        return callback error callback error if error?
        callback null, inList

  canDiscoverAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
      )

    discoverAsWhitelist = _.cloneDeep toDevice.discoverAsWhitelist
    unless discoverAsWhitelist
      discoverAsWhitelist = []
      discoverAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, discoverAsWhitelist, toDevice.discoverAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

#一般设备只能接收目的设备的广播消息
  canReceive: (fromDevice, toDevice, message, callback) =>
#    间接实现多参数
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
      )

    @_checkLists fromDevice, toDevice, toDevice.receiveWhitelist, toDevice.receiveBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

#  其它设备是否可以代替目的设备接收目的设备的sent,receive等信息
  canReceiveAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
      )

    receiveAsWhitelist = _.cloneDeep toDevice.receiveAsWhitelist
    unless receiveAsWhitelist
      receiveAsWhitelist = []
      receiveAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, receiveAsWhitelist, toDevice.receiveAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canSend: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
      )

    defaultAuth = @_check_authority(fromDevice,toDevice)

    @_s_checkLists fromDevice, toDevice, toDevice.sendWhitelist, toDevice.sendBlacklist, defaultAuth, (error, inList) =>
      return callback error callback error if error?
      callback null, inList

  canSendAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
      )

    sendAsWhitelist = _.cloneDeep toDevice.sendAsWhitelist
    unless sendAsWhitelist
      sendAsWhitelist = []
      sendAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, sendAsWhitelist, toDevice.sendAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  _resolveList: (list, callback) =>
    return callback null, list unless _.isArray list
    async.map list, @uuidAliasResolver.resolve, callback

  _s_isSameOwner: (fromDevice,toDevice) =>
    return false if !fromDevice.owner || !toDevice.owner
    return fromDevice.owner == toDevice.owner

  _check_authority: (fromDevice,toDevice) =>

    authority = toDevice.authority

    switch authority
      when "public"
        defaultAuth = true
      when "private"
        defaultAuth = false
      else
        defaultAuth = @_s_isSameOwner fromDevice,toDevice

    debug 'defaultAuth', defaultAuth
    return defaultAuth

module.exports = SimpleAuth
