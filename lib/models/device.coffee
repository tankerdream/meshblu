_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('hyga:model:device')
UUIDAliasResolver = require '../../src/uuid-alias-resolver'
Publisher = require '../Publisher'

publisher = new Publisher namespace: 'meshblu'

hyGaError = require './hyGaError'

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
    @PublishConfig = require '../publishConfig'
    {@uuid} = attributes
    delete attributes.uuid
    @set attributes


  fatalIfNoPrimary: (error) =>
    return unless error?
    return unless /ECONNREFUSED/.test(error.message) || /no primary server available/.test(error.message)
    console.error 'FATAL: database error', error
    process.exit 1

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
      
      debug 'token', token
      debug 'device.token', device.token
      return callback null, null if device.token == token
#       与_hashedToken之处在于不会随着机器的不同而值不同,这是root token与其他token的根本区别,所以验证和加密的方法跟其他的不同
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

    @findCachedDevice @uuid, (error, device) =>
      return callback error if error?
      if device?
        @fetch.cache = device
        return callback null, device

      @devices.findOne _id: @uuid, (error, device) =>
        @fatalIfNoPrimary error
        device.uuid = device._id
        delete device._id
        @fetch.cache = device
        return callback error if error?
        return callback hyGaError(404,'Device not founds') unless device?
        @cacheDevice device
        callback null, @fetch.cache

  generateAndStoreTokenInCache: (callback=->)=>
    token = @generateToken()
    @_hashToken token, (error, hashedToken) =>
      return callback error if error?

      debug 'generateAndStoreTokenInCache', hashedToken
      @_storeSessionTokenInCache hashedToken, (error) =>
        return callback error if error?
        callback null, token

  removeTokenFromCache: (token, callback=->) =>
    return callback null, false unless @redis?.del?
    @_hashToken token, (error, hashedToken) =>
      return callback error if error?
      @redis.del "meshblu-token-cache:#{@uuid}:#{hashedToken}", callback

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
    debug 'save', @attributes
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
    @attributes = _.extend @attributes, @sanitize(attributes)
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
        @update $set: {"hyga.tokens.#{hashedToken}" : tokenData}, callback

#  判断修改后的uuid与当前的uuid是否一致
  validate: (callback) =>
    if @attributes.uuid? && @uuid != @attributes.uuid
      return callback new Error('Cannot modify uuid',400), false
    callback null, true

# 验证根token的hash
  verifyRootToken: (ogToken,callback=->) =>

    @fetch (error, attributes={}) =>

      debug "verifyRootToken attributes.token ", attributes.token
      return callback error, false if error?
      return callback null, false unless attributes.token?

      bcrypt.compare ogToken, attributes.token, (error, verified) =>
        return callback error if error?
        debug "verifyRootToken: bcrypt.compare results: #{error}, #{verified}"
        @_hashToken ogToken, (error, hashedToken) =>
          return callback error if error?
          @_storeTokenInCache hashedToken if verified
          callback null, verified

#  验证其它设备产生的临时token
  verifySessionToken: (token, callback=->) =>
    return callback null, false unless @redis?.exists?
    @_hashToken token, (error, hashedToken) =>
      return callback error if error?
      @redis.exists "ses:#{@uuid}:#{hashedToken}", callback

# 最后验证不通过,则将token存入黑名单中
  verifyToken: (token, callback=->) =>
    return callback hyGaError(401,'No token provided') unless token?

    @_isTokenInBlacklist token, (error, blacklisted) =>
      debug 'blacklist in ', blacklisted
      return callback error if error?
      return callback null, false if blacklisted

      @_hashToken token, (error, hashedToken) =>
        return callback error if error?

        debug 'hashedToken', hashedToken

        @_verifyTokenInCache hashedToken, (error, verified) =>
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

#    params = _.cloneDeep params
#    keys   = _.keys(params)

#    if _.all(keys, (key) -> _.startsWith key, '$')
#      params['$set'] ?= {}
#      params['$set']._id = @uuid
#    else
#      params._id = @uuid

    debug 'update', @uuid, params
#    将设备存入devices所在的mongodb数据库
    @devices.update _id: @uuid, params, (error, result) =>
      @fatalIfNoPrimary error
      return callback @sanitizeError(error) if error?
#    若配置redis，则将设备原来的信息从redis缓存中清除
      @clearCache @uuid, =>
        @fetch.cache = null
        callback null, true

# 清除缓存中uuid和token的键值对
  _clearTokenCache: (callback=->) =>
    return callback null, false unless @redis?.del?
    @redis.del "tokens:#{@uuid}", callback

#  更新设备的hashToken
  _hashDevice: (callback=->) =>
    # don't use @fetch to prevent side-effects
    @devices.findOne uuid: @uuid, (error, data) =>
      @fatalIfNoPrimary error
      return callback error if error?
      delete data.meshblu.hash if data?.meshblu?.hash
      @_hashToken JSON.stringify(data), (error, hashedToken) =>
        return callback error if error
        params = $set :
          'meshblu.hash': hashedToken
        debug 'updating hash', @uuid, params
        @devices.update uuid: @uuid, params, (error) =>
          @fatalIfNoPrimary error
          callback arguments...

# 每个机器临时产生的token
  _hashToken: (token, callback) =>

    hasher = crypto.createHash 'sha256'
    hasher.update token
    hasher.update @uuid
    hasher.update @config.token

    callback null, hasher.digest 'base64'

# 若设备配置成功,则向设备发送配置信息
  _sendConfig: (options, callback) =>
    {forwardedFor} = options
    
    @fetch (error, config) =>
      delete config.token
      return callback error if error?
      publishConfig = new @PublishConfig {@uuid, config, forwardedFor, database: {@devices}}
      publishConfig.publish => # don't wait for the publisher
      callback()

#  将设备的token和uuid的键值对保存在redis中
  _storeTokenInCache: (hashedToken, callback=->) =>
    return callback null, false unless @redis?.set?
    @redis.set "r:#{@uuid}:#{hashedToken}", '', callback

#  存储临时的token,保存时间为10分钟
  _storeSessionTokenInCache: (hashedToken, callback=->) =>
    return callback null, false unless @redis?.set?
    @redis.set "ses:#{@uuid}:#{hashedToken}", '', (err)=>
      callback err if err?
      @redis.expire "ses:#{@uuid}:#{hashedToken}", 600, callback

#    将最后验证失败的token放入黑名单,加快后续请求的验证速度
  _storeInvalidTokenInBlacklist: (token, callback=->) =>
    return callback null, false unless @redis?.set?
    @redis.set "meshblu-token-black-list:#{@uuid}:#{token}", '', callback


#    判断redis中是否有设备的指定token
  _verifyTokenInCache: (hashedToken, callback=->) =>
    return callback null, false unless @redis?.exists?
    @redis.exists "r:#{@uuid}:#{hashedToken}", callback

#    判断token是否在设备的token黑名单中
  _isTokenInBlacklist: (token, callback=->) =>
    return callback null, false unless @redis?.exists?
    @redis.exists "meshblu-token-black-list:#{@uuid}:#{token}", callback

  pushList: (listName,list,callback=->) =>
    @devices.update {'uuid':@uuid}, {$addToSet:{"#{listName}":{$each:list}}},(error)=>
      return callback error if error?
      @clearCache @uuid, =>
        @fetch.cache = null
        callback null, true

  pullList: (listName,list,callback=->) =>
    @devices.update {'uuid':@uuid}, {$pullAll:{"#{listName}":list}},(error)=>
      return callback error if error?
      @clearCache @uuid, =>
        @fetch.cache = null
        callback null, true

module.exports = Device
