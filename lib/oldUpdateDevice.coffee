_  = require 'lodash'
debug = require('debug')('meshblu:oldUpdateDevice')
Device = require './models/device'

#更新设备参数
module.exports = (uuid, params={}, callback=_.noop, dependencies={})->
  device = new Device uuid: uuid, dependencies

  delete params.configureBlacklist

#  banArray = [
#    "owner"
#    "authority"
#    "configureWhitelist"
#    "configureBlacklist"
#    "discoverWhitelist"
#    "discoverBlacklist"
#    "sendWhitelist"
#    "sendBlacklist"
#  ]
#
#  for key, value of params
#    return callback {code:604, error : {message: "Bad arguments"}} if _.includes banArray, key

  debug 'params',params

  device.set params

  device.save (error) =>
    debug 'save',error
    return callback error if error?
    device.fetch callback
