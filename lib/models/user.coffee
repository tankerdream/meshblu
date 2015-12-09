_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('meshblu:model:user')

class User
  constructor: (attributes={}, dependencies={}) ->
    @users = dependencies.database?.devices ? require('../database').users
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
  verify: (psd, callback=->) =>
    return callback new Error('No password provided') unless psd?
    @_verifyPsdInCache psd, (error, verified) =>
      return callback error if error?
      return callback null, true if verified

      @verifyRootPsd psd, (error, verified) =>
        return callback error if error?
        return callback null, true if verified
        return callback null, false

# 根据uuid查找设备,若redis不存在device,则从mongoDB中找到device并将其缓存入redis中
  fetch: (callback=->) =>
    return _.defer callback, null, @fetch.cache if @fetch.cache?

    @findCachedUser @uuid, (error, user) =>
      return callback error if error?
      if user?
        @fetch.cache = user
        return callback null, user

      @users.findOne uuid: @uuid, {_id: false}, (error, user) =>
        @fetch.cache = user
        return callback new Error('User not found') unless user?
        @cacheUser user
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

  findCachedUser : (uuid, callback) ->

    cachedKey = @redis.CACHE_KEY + uuid

    debug 'checking redis cache', cachedKey
    @redis.get cachedKey, (error, data) ->
      return callback error if error?
      data = JSON.parse data if data
      debug 'cache results', data?.uuid
      callback null, data

  cacheUser : (user) ->
      if user
        @redis.setex @redis.CACHE_KEY + user.uuid, @redis.CACHE_TIMEOUT, JSON.stringify(user), _.noop

#    验证根mongodb中的psd
  verifyRootPsd: (ogPsd, callback=->) =>
    debug "verifyRootToken: ", ogPsd

    @fetch (error, attributes={}) =>
      return callback error, false if error?
      return callback null, false unless attributes.psd?
      callback null,(ogPsd == attributes.psd)

#    判断redis中是否有设备的指定token
  _verifyPsdInCache: (psd, callback=->) =>
    return callback null, false unless @redis?.sismember?
    @redis.sismember "psd:#{@uuid}", psd, callback

module.exports = User