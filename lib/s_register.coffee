_             = require 'lodash'
debug         = require('debug')('meshblu:s_register')
logEvent      = require './logEvent'

module.exports = (owner={},device={}, callback=_.noop, dependencies={}) =>

# 通过`node-uuid`或`dependencies.uuid`产生的唯一的uuid
# 存储设备等相关信息，若配置`mongodb`，则存储在相应`url`的数据库中；若没有配置，则通过`nedb`存储在文件中。

  uuid      = owner.uuid
  psd       = owner.psd

  return callback Error('Invalid owner'),null unless uuid? && psd?

  s_database  = dependencies.s_database ? require './s_database'
  s_authUser  = dependencies.s_authUser ? require('./s_authUser')
  register    = dependencies.register ? require('./register')

  {users}     = s_database

  s_authUser uuid, psd, (error, user) =>
    return callback error,null if error?
    return callback Error('No permission to add device'),null unless user?

    device = _.cloneDeep device

    register device,(error, newDevice)=>
      return callback error,null if error?
      return callback Error('Register failure'),null unless newDevice

      users.update {"uuid":user.uuid},{$addToSet:{"devices":newDevice.uuid}}
      callback null,newDevice