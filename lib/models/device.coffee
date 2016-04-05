_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('meshblu:model:device')
UUIDAliasResolver = require '../../src/uuid-alias-resolver'
Publisher = require '../Publisher'

publisher = new Publisher namespace: 'meshblu'

class Device
  constructor: (attributes={}, dependencies={}) ->
    @devices = dependencies.database?.devices ? require('../database').devices
    @getGeo = dependencies.getGeo ? require '../getGeo'
    @generateToken = dependencies.generateToken ? require '../generateToken'
    @clearCache = dependencies.clearCache ? require '../clearCache'
    @config = dependencies.config ? require '../../config'
    @redis = dependencies.redis ? require '../redis'
    @findCachedDevice = dependencies.findCachedDevice ? require '../findCachedDevice'
    @cacheDevice = dependencies.cacheDevice ? require '../cacheDevice'
    aliasServerUri = @config.aliasServer?.uri
    @uuidAliasResolver = new UUIDAliasResolver {}, {@redis, aliasServerUri}
    @PublishConfig = require '../publishConfig'
    @set attributes
    {@uuid} = attributes

# 根据ip地址添加设备的物理地址
  addGeo: (callback=->) =>
    return _.defer callback unless @attributes.ipAddress?

    @getGeo @attributes.ipAddress, (error, geo) =>
      @attributes.geo = geo
      callback()

# 添加hashToken到attributes.token和redis中
  addHashedToken: (callback=->) =>
    token = @attributes.token
    return _.defer callback, null, null unless token?

    @fetch (error, device) =>
      return callback error if error?
      return callback null, null if device.token == token

      bcrypt.hash token, 8, (error, hashedToken) =>
        @attributes.token = hashedToken if hashedToken?
        @_storeTokenInCache hashedToken if hashedToken?
        callback error

  addOnlineSince: (callback=->) =>
    @fetch (error, device) =>
      return callback error if error?

      if !device.online && @attributes.online
        @attributes.onlineSince = new Date()

      callback()

# 根据uuid查找设备,若redis不存在device,则从mongoDB中找到device并将其缓存入redis中
  fetch: (callback=->) =>
    return _.defer callback, null, @fetch.cache if @fetch.cache?

    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @findCachedDevice uuid, (error, device) =>
        return callback error if error?
        if device?
          @fetch.cache = device
          return callback null, device

        @devices.findOne uuid: uuid, {_id: false}, (error, device) =>
          @fetch.cache = device
          return callback error if error?
          return callback new Error('Device not founds') unless device?
          @cacheDevice device
          callback null, @fetch.cache

  generateAndStoreTokenInCache: (callback=->)=>
    token = @generateToken()
    @_hashToken token, (error, hashedToken) =>
      return callback error if error?
      @_storeTokenInCache hashedToken, (error) =>
        return callback error if error?
        callback null, token

  removeTokenFromCache: (token, callback=->) =>
    return callback null, false unless @redis?.del?
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @_hashToken token, (error, hashedToken) =>
        return callback error if error?
        @redis.del "meshblu-token-cache:#{uuid}:#{hashedToken}", callback

# 重置token
  resetToken: (callback) =>
    newToken = @generateToken()
    @set token: newToken
    @save (error) =>
      return callback error if error?
      @_clearTokenCache()
      callback null, newToken

# 撤销其它设备访问时设置的token
  revokeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      @_hashToken token, (error, hashedToken) =>
        return callback error if error?

        @removeTokenFromCache token
        @update $unset : {"meshblu.tokens.#{hashedToken}"}, callback

# 处理参数,使其符合存入mongoDB中的要求,防止非法操作mongoDB
  sanitize: (params) =>
    return params unless _.isObject(params) || _.isArray(params)

    return _.map params, @sanitize if _.isArray params

    params = _.omit params, (value, key) -> key[0] == '$'
    return _.mapValues params, @sanitize

  sanitizeError: (error) =>
    message = error?.message ? error
    message = "Unknown error" unless _.isString message

    new Error message.replace("MongoError: ")

# 注册设备，保存设备
  save: (callback=->) =>
    debug 'save','save'
    @validate (error, isValid) =>
      return callback error unless isValid

      async.series [
        @addGeo
        @addHashedToken
        @addOnlineSince
      ], (error) =>
        return callback error if error?
        debug 'save', @attributes
        @update $set: @attributes, callback

#  设置设备的参数
  set: (attributes)=>
    @attributes ?= {}
    @attributes = _.extend {}, @attributes, @sanitize(attributes)
    debug 'set attributes', @attributes
    @attributes.online = !!@attributes.online if @attributes.online?

# 存储设备的token
  storeToken: (tokenOptions, callback=_.noop)=>
    {token, tag} = tokenOptions
    @fetch (error, attributes) =>
      return callback error if error?

      @_hashToken token, (error, hashedToken) =>
        return callback error if error?

        debug 'storeToken', token, hashedToken
        tokenData = createdAt: new Date()
        tokenData.tag = tag if tag?
        @_storeTokenInCache hashedToken
        @update $set: {"meshblu.tokens.#{hashedToken}" : tokenData}, callback


#  判断修改后的uuid与当前的uuid是否一致
  validate: (callback) =>
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      if @attributes.uuid? && uuid != @attributes.uuid
        return callback new Error('Cannot modify uuid',400), false
      callback null, true

#    验证根token的hash
  verifyRootToken: (ogToken, callback=->) =>
    debug "verifyRootToken: ", ogToken

    @fetch (error, attributes={}) =>
      return callback error, false if error?
      return callback null, false unless attributes.token?
      bcrypt.compare ogToken, attributes.token, (error, verified) =>
        return callback error if error?
        debug "verifyRootToken: bcrypt.compare results: #{error}, #{verified}"
        @_hashToken ogToken, (error, hashedToken) =>
          return callback error if error?
          @_storeTokenInCache hashedToken if verified
          callback null, verified

#  验证meshblu中token的hash
  verifySessionToken: (token, callback=->) =>
    @_hashToken token, (error, hashedToken) =>
      return callback error if error?
      @fetch (error, attributes) =>
        return callback error if error?

        verified = attributes?.meshblu?.tokens?[hashedToken]?
        @_storeTokenInCache hashedToken if verified
        callback null, verified

# 最后验证不通过,则将token存入黑名单中
  verifyToken: (token, callback=->) =>
    return callback "{code:401,{error:'No token provided'}}" unless token?

    @_isTokenInBlacklist token, (error, blacklisted) =>
      return callback error if error?
      return callback null, false if blacklisted

      @_verifyTokenInCache token, (error, verified) =>
        return callback error if error?
        return callback null, true if verified

        @verifySessionToken token, (error, verified) =>
          return callback error if error?
          return callback null, true if verified

          @verifyRootToken token, (error, verified) =>
            return callback error if error?
            return callback null, true if verified

            @_storeInvalidTokenInBlacklist token
            return callback null, false


# 将设备信息存入mongodb
  update: (params, rest...) =>
    [callback] = rest
    [options, callback] = rest if _.isPlainObject(rest[0])
    options ?= {}

    params = _.cloneDeep params
    keys   = _.keys(params)

    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      if _.all(keys, (key) -> _.startsWith key, '$')
        params['$set'] ?= {}
        params['$set'].uuid = uuid
      else
        params.uuid = uuid

      debug 'update', uuid, params
#    将设备存入devices所在的mongodb数据库
      @devices.update uuid: uuid, params, (error, result) =>
        return callback @sanitizeError(error) if error?
#    若配置redis，则将设备原来的信息从redis缓存中清除
        @clearCache uuid, =>
          @fetch.cache = null
          @_hashDevice (hashDeviceError) =>
            @_sendConfig options, (sendConfigError) =>
              return callback @sanitizeError(hashDeviceError) if hashDeviceError?
              callback sendConfigError

# 清除缓存中uuid和token的键值对
  _clearTokenCache: (callback=->) =>
    return callback null, false unless @redis?.del?
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @redis.del "tokens:#{uuid}", callback

  _lookupAlias: (alias, callback) =>
    @uuidAliasResolver.resolve alias, callback

#  更新设备的hashToken
  _hashDevice: (callback=->) =>
    # don't use @fetch to prevent side-effects
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      debug '_hashDevice', uuid
      @devices.findOne uuid: uuid, (error, data) =>
        return callback error if error?
        delete data.meshblu.hash if data?.meshblu?.hash
        @_hashToken JSON.stringify(data), (error, hashedToken) =>
          return callback error if error
          params = $set :
            'meshblu.hash': hashedToken
          debug 'updating hash', uuid, params
          @devices.update uuid: uuid, params, callback

  _hashToken: (token, callback) =>
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      return callback new Error 'Invalid Device UUID' unless uuid?

      hasher = crypto.createHash 'sha256'
      hasher.update token
      hasher.update uuid
      hasher.update @config.token

      callback null, hasher.digest 'base64'

# 若设备配置成功,则向设备发送配置信息
  _sendConfig: (options, callback) =>
    {forwardedFor} = options
    @fetch (error, config) =>
      delete config.token
      return callback error if error?
      @_lookupAlias @uuid, (error, uuid) =>
        return callback error if error?
        publishConfig = new @PublishConfig {uuid, config, forwardedFor, database: {@devices}}
        publishConfig.publish => # don't wait for the publisher
        callback()

#  将设备的token和uuid的键值对保存在redis中
  _storeTokenInCache: (hashedToken, callback=->) =>
    return callback null, false unless @redis?.set?
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @redis.set "meshblu-token-cache:#{uuid}:#{hashedToken}", '', callback

#    将最后验证失败的token放入黑名单,加快后续请求的验证速度
  _storeInvalidTokenInBlacklist: (token, callback=->) =>
    return callback null, false unless @redis?.set?
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @redis.set "meshblu-token-black-list:#{uuid}:#{token}", '', callback

#    判断redis中是否有设备的指定token
  _verifyTokenInCache: (token, callback=->) =>
    return callback null, false unless @redis?.exists?
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @_hashToken token, (error, hashedToken) =>
        return callback error if error?
        @redis.exists "meshblu-token-cache:#{uuid}:#{hashedToken}", callback

#    判断token是否在设备的token黑名单中
  _isTokenInBlacklist: (token, callback=->) =>
    return callback null, false unless @redis?.exists?
    @_lookupAlias @uuid, (error, uuid) =>
      return callback error if error?
      @redis.exists "meshblu-token-black-list:#{uuid}:#{token}", callback

  pushList: (listName,list,callback=->) =>
    @devices.update {'uuid':@uuid}, {$addToSet:{"#{listName}":{$each:list}}},(error)->
      return callback error if error?
#      TODO 清理redis,config通知
      return callback null

  pullList: (listName,list,callback=->) =>
    @devices.update {'uuid':@uuid}, {$pullAll:{"#{listName}":list}},(error)->
      return callback error if error?
      return callback null

module.exports = Device
