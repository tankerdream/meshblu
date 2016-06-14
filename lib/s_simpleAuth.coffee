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
    @authSessionToken ?= require './authSessionToken'
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
  canConfigure: (fromDevice, toDevice, callback) =>

    debug 'canconfigure'
    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice
    debug 'canconfigure before owner'
    return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid || toDevice.owner == fromDevice.uuid
    debug 'canconfigure after owner'
    debug 'toDevice.configureList', toDevice.configureList
    @_checkLists fromDevice, toDevice, toDevice.configureList, null, false, (error, inList) =>
      return callback error if error?
      return callback null, true if inList
      @asyncCallback(null, false, callback)

  canConfigureList: (fromDevice, toDevice, message, callback) =>

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice
    return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid || toDevice.owner == fromDevice.uuid

    @_checkLists fromDevice, toDevice, toDevice.configureList, null, false, (error, inList) =>
      return callback error if error?
      return callback null, true if inList
      if message?.sesToken && (message.listName != 'configureList')
        return @authSessionToken(
          toDevice.uuid
          message.sesToken
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
        )
      @asyncCallback(null, false, callback)

  canDiscover: (fromDevice, toDevice, sesToken, callback) =>

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    defaultAuth = @_check_authority(fromDevice,toDevice)

    debug 'canDiscover defaultAuth', defaultAuth

    @_s_checkLists fromDevice, toDevice, toDevice.whitelist, toDevice.blacklist, defaultAuth, (error, inList) =>
      return callback error callback error if error?
      return callback null, inList

      if sesToken?
        return @authSessionToken(
          toDevice.uuid
          sesToken
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
        )
      @asyncCallback(null, false, callback)

  canSend: (fromDevice, toDevice, token, callback) =>

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    defaultAuth = @_check_authority(fromDevice,toDevice)

    @_s_checkLists fromDevice, toDevice, toDevice.whitelist, toDevice.blacklist, defaultAuth, (error, inList) =>
      return callback error callback error if error?
      return callback null, true if inList

      if token?
        return @authSessionToken(
          toDevice.uuid
          token
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
        )
      @asyncCallback(null, false, callback)

  _resolveList: (list, callback) =>
    return callback null, list unless _.isArray list
    async.map list, @uuidAliasResolver.resolve, callback

  _s_isSameOwner: (fromDevice,toDevice) =>
    debug 'fromDevice owner', fromDevice.owner
    debug 'toDevice owner', toDevice.owner
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
