_ = require 'lodash'
config = require './../config'
redis = require './redis'
debug = require('debug')('meshblu:findCachedDevice')

#在缓存中查找设备
findCachedDevice = (uuid, callback) ->
  unless config.redis && config.redis.host
    callback null
    return

  cachedKey = redis.CACHE_KEY + uuid

  debug 'checking redis cache', cachedKey
  redis.get cachedKey, (error, data) ->
    return callback error if error?
    data = JSON.parse data if data
    debug 'cache results', data?.uuid
    callback null, data

module.exports = findCachedDevice
