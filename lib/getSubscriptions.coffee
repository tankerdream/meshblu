SubscriptionGetter = require './SubscriptionGetter'

#获取订阅了emitterUuid设备type类型消息的设备uuid列表,然后过滤得到可以发送的设备的uuid列表
module.exports = (emitterUuid, type, callback) ->
  subscriptionGetter = new SubscriptionGetter emitterUuid: emitterUuid, type: type
  subscriptionGetter.get callback
