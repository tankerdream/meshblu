config = require '../config'
redis = require './redis'
MessageIOEmitter = require './messageIOEmitter'
debug = require('debug')('meshblu:create-message-io-emitter')

#配置、管理消息发送器
#config.js配置有redis主机时，添加redis发送器
#返回发送函数，发送函数对发送数组中的每个发送器进行操作
module.exports = (io) =>
  messageIOEmitter = new MessageIOEmitter
  if config.redis?.host
    debug 'adding redis emitter'
    redisIoEmitter = require('socket.io-emitter')(redis.client)
    messageIOEmitter.addEmitter redisIoEmitter
  else
    debug 'adding io emitter'
    messageIOEmitter.addEmitter io

  return messageIOEmitter.emit
