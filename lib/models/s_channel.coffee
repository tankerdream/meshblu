_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('show:model:s_channel')

class S_Channel
  constructor: (attributes={}, dependencies={}) ->
    @s_channels = dependencies.database?.s_channels ? require('../s_database').s_channels
    @generateToken = dependencies.generateToken ? require '../generateToken'
    @clearCache = dependencies.clearCache ? require '../clearCache'
    @config = dependencies.config ? require '../../config'
    @redis = dependencies.redis ? require '../redis'
    @set attributes
    {@uuid} = attributes

#  设置用户的参数
  set: (attributes)=>
    @attributes ?= {}
    @attributes = _.extend {}, @attributes, @sanitize(attributes)
    @attributes.online = !!@attributes.online if @attributes.online?

# 验证密码
  verifyToken: (token, callback=->) =>
    return callback new Error('No password provided') unless token?
    @_verifyTokenInCache token, (error, verified) =>
      return callback error if error?
      return callback null, true if verified

      @verifyRootToken token, (error, verified) =>
        return callback error if error?
        return callback null, true if verified
        return callback null, false

# 根据uuid查找设备,若redis不存在device,则从mongoDB中找到device并将其缓存入redis中
  fetch: (callback=->) =>
    return _.defer callback, null, @fetch.cache if @fetch.cache?

    @findCachedS_Channel @uuid, (error, s_channel) =>
      return callback error if error?
      if s_channel?
        @fetch.cache = s_channel
        return callback null, s_channel

      @s_channels.findOne uuid: @uuid, {_id: false}, (error,s_channel) =>
        @fetch.cache = s_channel
        return callback new Error('Channel not found') unless s_channel?
        @cacheS_Channel s_channel
        callback null, @fetch.cache

# 处理参数,使其符合存入mongoDB中的要求
  sanitize: (params) =>
    return params unless _.isObject(params) || _.isArray(params)

    return _.map params, @sanitize if _.isArray params

    params = _.omit params, (value, key) -> key[0] == '$'
    return _.mapValues params, @sanitize

  sanitizeError: (error) =>
    message = error?.message ? error
    message = "Unknown error" unless _.isString message

    new Error message.replace("MongoError: ")

  findCachedS_Channel : (uuid, callback) ->

    cachedKey = @redis.CACHE_KEY + uuid

    debug 'checking redis cache', cachedKey
    @redis.get cachedKey, (error, data) ->
      return callback error if error?
      data = JSON.parse data if data
      debug 'cache results', data?.uuid
      callback null, data

  cacheS_Channel : (s_channel) ->
      if s_channel
        @redis.setex @redis.CACHE_KEY + s_channel.uuid, @redis.CACHE_TIMEOUT, JSON.stringify(s_channel), _.noop

#    验证根mongodb中的token
  verifyRootToken: (ogToken, callback=->) =>
    debug "verifyRootToken: ", ogToken

    @fetch (error, attributes={}) =>
      return callback error, false if error?
      return callback null, false unless attributes.token?
      callback null,(ogToken == attributes.token)

#    判断redis中是否有设备的token
  _verifyTokenInCache: (token, callback=->) =>
    return callback null, false unless @redis?.sismember?
    @redis.sismember "token:#{@uuid}", token, callback

module.exports = S_Channel