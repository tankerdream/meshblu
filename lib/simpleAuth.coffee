util = require "./util"
bcrypt = require "bcrypt"
_ = require "lodash"

#设备各种属性的检测
class SimpleAuth

  constructor: (@dependencies={}) ->
    @authDevice = @dependencies.authDevice || require './authDevice'

  asyncCallback : (error, result, callback) =>
    _.defer( => callback(error, result))

# 判断源设备是否在目的设备的白名单或黑名单中
  checkLists: (fromDevice, toDevice, whitelist, blacklist, openByDefault) =>
    return false if !fromDevice || !toDevice

    return true if toDevice.uuid == fromDevice.uuid

    return true if _.contains whitelist, '*'

    return  _.contains(whitelist, fromDevice.uuid) if whitelist?

    return !_.contains(blacklist, fromDevice.uuid) if blacklist?

    openByDefault

#    判断源设备是否可以配置目标设备
  canConfigure: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, true, callback) if @checkLists fromDevice, toDevice, toDevice?.configureWhitelist, toDevice?.configureBlacklist, false

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid

    if toDevice.owner?
      return @asyncCallback(null, true, callback) if toDevice.owner == fromDevice.uuid
    else
      return @asyncCallback(null, true, callback) if util.sameLAN(fromDevice.ipAddress, toDevice.ipAddress)

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    return @asyncCallback(null, false, callback)

  canConfigureAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    configureAsWhitelist = _.cloneDeep toDevice?.configureAsWhitelist
    unless configureAsWhitelist
      configureAsWhitelist = []
      configureAsWhitelist.push toDevice.owner if toDevice?.owner

    result = @checkLists fromDevice, toDevice, configureAsWhitelist, toDevice?.configureAsBlacklist, true
    @asyncCallback(null, result, callback)

  canDiscover: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, true, callback) if @checkLists fromDevice, toDevice, toDevice?.discoverWhitelist, toDevice?.discoverBlacklist, true

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    return @asyncCallback(null, false, callback)

  canDiscoverAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    discoverAsWhitelist = _.cloneDeep toDevice?.discoverAsWhitelist
    unless discoverAsWhitelist
      discoverAsWhitelist = []
      discoverAsWhitelist.push toDevice.owner if toDevice?.owner

    result = @checkLists fromDevice, toDevice, discoverAsWhitelist, toDevice?.discoverAsBlacklist, true
    @asyncCallback(null, result, callback)

#
  canReceive: (fromDevice, toDevice, message, callback) =>
#    间接实现多参数
    if _.isFunction message
      callback = message
      message = null

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    result = @checkLists fromDevice, toDevice, toDevice?.receiveWhitelist, toDevice?.receiveBlacklist, true
    @asyncCallback(null, result, callback)

  canReceiveAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    receiveAsWhitelist = _.cloneDeep toDevice?.receiveAsWhitelist
    unless receiveAsWhitelist
      receiveAsWhitelist = []
      receiveAsWhitelist.push toDevice.owner if toDevice?.owner

    result = @checkLists fromDevice, toDevice, receiveAsWhitelist, toDevice?.receiveAsBlacklist, true
    @asyncCallback(null, result, callback)

  canSend: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    result = @checkLists fromDevice, toDevice, toDevice?.sendWhitelist, toDevice?.sendBlacklist, true
    @asyncCallback(null, result, callback)

  canSendAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    sendAsWhitelist = _.cloneDeep toDevice?.sendAsWhitelist
    unless sendAsWhitelist
      sendAsWhitelist = []
      sendAsWhitelist.push toDevice.owner if toDevice?.owner

    result = @checkLists fromDevice, toDevice, sendAsWhitelist, toDevice?.sendAsBlacklist, true
    @asyncCallback(null, result, callback)


module.exports = SimpleAuth
