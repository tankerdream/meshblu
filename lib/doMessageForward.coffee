_ = require 'lodash'
async = require 'async'
messageIOEmitter = require('./createMessageIOEmitter')()
debug = require('debug')('meshblu:doMessageForward')

module.exports = (forwarders=[], message, fromUuid, callback=_.noop, dependencies={}) ->
  debug 'doMessageForward', forwarders, message
  async.map forwarders, (forwarder, cb=->) =>
#    这里的message已经不是传进来的参数message了!
    message ?= {}
    message.forwardedFor ?= []

    if _.contains message.forwardedFor, fromUuid
      debug 'Refusing to forward message to a device already in forwardedFor', fromUuid
      return cb()

    message.forwardedFor.push fromUuid
    message.devices = [forwarder]
    message.fromUuid = fromUuid
#    后两个参数作为一个数组传入message,作为messages的一个元素
    cb null, forwardTo: forwarder, message: message
  , (error, messages) =>
    callback error, _.compact(messages)
