_             = require 'lodash'
debug         = require('debug')('meshblu:s_register')
generateToken = require './generateToken'
logEvent      = require './logEvent'

module.exports = (owner,device={}, callback=_.noop, dependencies={}) ->

# 通过`node-uuid`或`dependencies.uuid`产生的唯一的uuid
# 存储设备等相关信息，若配置`mongodb`，则存储在相应`url`的数据库中；若没有配置，则通过`nedb`存储在文件中。
  uuid         = dependencies.uuid || require 'node-uuid'

  {devices}    = database

  s_database     = dependencies.s_database ? require './s_database'
  {users}     = s_database

  device = _.cloneDeep device


  debug "registering with owner", device


