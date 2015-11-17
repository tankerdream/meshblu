_ = require 'lodash'
redis = require './redis'

#将设备放入redis中
cacheDevice = (device) ->
  if device
    redis.setex redis.CACHE_KEY + device.uuid, redis.CACHE_TIMEOUT, JSON.stringify(device), _.noop

module.exports = cacheDevice
