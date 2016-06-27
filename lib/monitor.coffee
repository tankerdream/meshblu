redis = require './redis'
debug = require('debug')('monitor')

cnt = (channelUuid, type, length = 1) ->
  return  unless channelUuid? or apiType?

  redis.hincrby "cnt:#{channelUuid}", "#{type}", length, (error, result) ->
    debug 'error', error, result if error
    return

module.exports = cnt