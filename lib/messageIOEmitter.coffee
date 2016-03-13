_ = require 'lodash'
config = require '../config'
redis = require './redis'
debug = require('debug')('meshblu:message-io-emitter')

#消息发送器
class MessageIOEmitter
  constructor: (dependencies={}) ->
    @emitters = []

  addEmitter: (emitter) =>
    @emitters.push emitter

  emit: (channel, topic, data) =>
    _.each @emitters, (emitter) ->
      debug 'emit', channel, topic, data
#      channel为socket重的room,topic为触发的事件
      emitter.in(channel).emit(topic, data)

module.exports = MessageIOEmitter
