_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('hyga:model:s_channel')

class S_Channel
  constructor: (attributes={}, dependencies={}) ->
    @s_channels = dependencies.database?.s_channels ? require('../s_database').s_channels
    @generateToken = dependencies.generateToken ? require '../generateToken'
    @clearCache = dependencies.clearCache ? require '../clearCache'
    @config = dependencies.config ? require '../../config'
    @redis = dependencies.redis ? require '../redis'
    @uuid = attributes.uuid
    delete attributes.uuid
    @set attributes

#  设置用户的参数
  set: (attributes)=>
    @attributes ?= {}
    @attributes = _.extend {}, @attributes, @sanitize(attributes)
    @attributes.online = !!@attributes.online if @attributes.online?

# 根据uuid查找设备,若redis不存在device,则从mongoDB中找到device并将其缓存入redis中
  fetch: (callback=->) =>
    return _.defer callback, null, @fetch.cache if @fetch.cache?

    @findCachedS_Channel @uuid, (error, s_channel) =>
      return callback error if error?

      if s_channel?
        @fetch.cache = s_channel
        return callback null, s_channel

      @s_channels.findOne _id: @uuid, {_id: false}, (error,s_channel) =>
        debug 'findOne channel', error, s_channel
        s_channel.uuid = s_channel._id
        delete s_channel._id
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

# 注册设备是验证的token
  verifyToken: (tokenPrefix, token, callback=->) =>
    return callback hyGaError(400,"No #{tokenPrefix}Token provided") unless token?

    @_hashToken token, (error, hashedToken) =>
      return callback error if error?
      debug 'hashed token', hashedToken

      @_verifyTokenInCache tokenPrefix, hashedToken, (error, verified) =>

        debug 'verify tokenInCache', error, verified
        return callback error if error?
        return callback null, true if verified

        @verifyRootToken tokenPrefix, token, hashedToken, (error, verified) =>

          debug 'verify tokenInRoot', error, verified
          return callback error if error?
          return callback null, true if verified
          return callback null, false

#    验证根mongodb中的token
  verifyRootToken: (tokenPrefix, ogToken, hashedToken, callback=->) =>
    debug "verifyRootToken: ", ogToken

    @fetch (error, attributes={}) =>
      debug "attribute type: ", typeof attributes
      debug "attribute type: ", attributes
      return callback error, false if error?
      return callback null, false unless attributes["#{tokenPrefix}Token"]?

      bcrypt.compare ogToken, attributes["#{tokenPrefix}Token"], (error, verified) =>
        return callback error if error?
        debug "verifyRootToken: bcrypt.compare results: #{error}, #{verified}"
        @_storeTokenInCache  tokenPrefix, hashedToken if verified
        callback null, verified

  _hashToken: (token, callback) =>

    hasher = crypto.createHash 'sha256'
    hasher.update token
    hasher.update @uuid
    hasher.update @config.token

    callback null, hasher.digest 'base64'
#    判断redis中是否有设备的token
  _verifyTokenInCache: (tokenPrefix, hashedToken, callback=->) =>
    return callback null, false unless @redis?.exists?
    @redis.exists "#{tokenPrefix}:#{@uuid}:#{hashedToken}", callback

#  将dmToken键值对保存在redis中
  _storeTokenInCache: (tokenPrefix, hashedToken, callback=->) =>
    return callback null, false unless @redis?.set?
    @redis.set "#{tokenPrefix}:#{@uuid}:#{hashedToken}", '', callback


module.exports = S_Channel