_  = require 'lodash'
Device = require './models/device'

module.exports = (uuid, params={}, callback=_.noop, dependencies={})->
  device = new Device uuid: uuid, dependencies

  delete params.configureBlacklist

  banArray = [
    "owner"
    "authority"
    "configureWhitlist"
    "configureBlacklist"
    "discoverWhitelist"
    "discoverBlacklist"
    "sendWhitelist"
    "sendBlacklist"
  ]

  for key, value of params
    return callback {code:604, error : {message: "Bad arguments"}} if _.includes banArray, key

  device.set params

  device.save (error) =>
#    console.log error
    return callback error if error?
    device.fetch callback
