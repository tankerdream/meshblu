_ = require 'lodash'
async = require 'async'

//将消息发送给设备在云端配置好的钩子
module.exports = (device, hooks, message, callback=_.noop, dependencies={}) ->
  MessageWebhook = dependencies.MessageWebhook ? require './MessageWebhook'
  hooks ?= []

  async.map hooks, (hook, cb=->) =>
    messageWebhook = new MessageWebhook device.uuid, hook
    messageWebhook.send message, (error) =>
      cb null, error
  , (error, errors) =>
    callback errors
