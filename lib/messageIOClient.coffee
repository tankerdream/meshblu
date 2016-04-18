_ = require 'lodash'
async = require 'async'
config = require '../config'
debug = require('debug')('meshblu:message-io-client')
{createClient} = require './redis'
{EventEmitter2} = require 'eventemitter2'
Subscriber = require './Subscriber'

s_securityImpl = require './s_getSecurityImpl'
getDevice = require './getDevice'
hyGaError = require('./models/hyGaError');

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

  subBroadcast: (fromDeivce, uuids, callback =  _.noop) =>

    async.each uuids, (uuid, done) =>
      getDevice uuid,(error,check)=>
        return callback error if error?
        s_securityImpl.canDiscover fromDeivce, check, (error, permission)=>

          debug 'subBroadcast error', error
          return callback error if error?

          debug 'subBroadcast permission', permission
          return callback hyGaError(401,'No permission', {uuid:uuid}) unless permission
          @subscriber.subscribe 'broadcast', uuid, done
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

    if _.contains channel, ':broadcast:'
      debug 'broadcast',message
      @emit 'broadcast', message
      return

    debug 'relay message', message
    debug 'channel', channel
    @emit 'message', message

module.exports = MessageIOClient