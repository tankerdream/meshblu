_ = require 'lodash'
async = require 'async'
config = require '../config'
debug = require('debug')('meshblu:message-io-client')
{createClient} = require './redis'
{EventEmitter2} = require 'eventemitter2'
Subscriber = require './Subscriber'

class MessageIOClient extends EventEmitter2
  @DEFAULT_SUBSCRIPTION_TYPES: ['received', 'config', 'data']
  @DEFAULT_UNSUBSCRIPTION_TYPES: ['received']

  constructor: ({namespace}={}, dependencies={}) ->
    namespace ?= 'meshblu'
    @subscriber = new Subscriber namespace: namespace
    @subscriber.on 'message', @_onMessage  #加入data,config的处理函数

  close: =>
    @subscriber.close()

  subscribe: (uuid, subscriptionTypes, callback) =>
    subscriptionTypes ?= MessageIOClient.DEFAULT_SUBSCRIPTION_TYPES
    async.each subscriptionTypes, (type, done) =>
      @subscriber.subscribe type, uuid, done
    , callback

  unsubscribe: (uuid, subscriptionTypes, callback) =>
    subscriptionTypes ?= MessageIOClient.DEFAULT_UNSUBSCRIPTION_TYPES

    debug 'unsubscribe',subscriptionTypes

    async.each subscriptionTypes, (type, done) =>
      @subscriber.unsubscribe type, uuid, done
    , callback


  _onMessage: (channel, message) =>
    if _.contains channel, ':config:'
      debug 'config',message
      @emit 'config', message
      return

    if _.contains channel, ':data:'
      @emit 'data', message
      return

    debug 'relay message', message
    debug 'channel', channel
    @emit 'message', message

module.exports = MessageIOClient