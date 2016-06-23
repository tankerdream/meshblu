async = require 'async'
bcrypt = require "bcrypt"
_ = require "lodash"
UUIDAliasResolver = require '../src/uuid-alias-resolver'

Device = require './models/device'
hyGaError = require './models/hyGaError'
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

          return callback hyGaError(401, 'Unauthorized'), false if resolvedBlacklist? && _.contains(resolvedBlacklist, fromDeviceUuid)

          return callback null, true if openByDefault

          @_resolveList whitelist, (error, resolvedWhitelist) =>

            return callback error if error?
            return callback null, _.contains(resolvedWhitelist, fromDeviceUuid) if resolvedWhitelist?

            callback null, openByDefault

# 不能使用sesToken调用的函数一定要预先删除 sesToken
  canConfigure: (fromDevice, toDevice, sesToken, callback) =>

    return callback null, true, true if fromDevice.uuid == toDevice.uuid || toDevice.owner == fromDevice.uuid

    return callback hyGaError(401,'Unauthorized') unless sesToken?
    @_authSesToken toDevice.uuid, sesToken, (error, verified) ->
      return callback error, verified

  canDiscover: (fromDevice, toDevice, sesToken, callback) =>

    return callback null, true, true if fromDevice.uuid == toDevice.uuid || toDevice.owner == fromDevice.uuid

    defaultAuth = @_check_authority(fromDevice,toDevice)

    debug 'canDiscover defaultAuth', defaultAuth

    @_s_checkLists fromDevice, toDevice, toDevice.whitelist, toDevice.blacklist, defaultAuth, (error, inList) =>
      return callback error if error?
      return callback null, inList

      return callback hyGaError(401,'Unauthorized') unless sesToken?
      @_authSesToken toDevice.uuid, sesToken, (error, verified) ->
        return callback error, verified

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

  _authSesToken: (uuid, sesToken, callback) =>

    device = new Device {uuid: uuid}
    device.verifySessionToken sesToken, (error, verified) =>
      return callback error, verified

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
