redis = require './redis'
debug = require('debug')('monitor')

countApi = (channelUuid, apiType) ->
  return  unless channelUuid? or apiType?
  redis.hincrby "cnt:#{channelUuid}", "#{apiType}", 1, (error, result) ->
    debug 'error', error, result if error
    return

module.exports = countApi
