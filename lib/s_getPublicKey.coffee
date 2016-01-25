_ = require 'lodash'
debug = require('debug')('s:getPublicKey')

_getKey = (device,callback) ->

  return callback {message:'No publicKey',code:404}, null unless device?.publicKey

  debug 'device', device
  name = device?.name || 'publicKey'
  publicKey = device?.publicKey
  callback null, {"#{name}": publicKey}

module.exports = (fromDevice,uuid, callback=_.noop, dependencies={}) ->
  return _getKey(fromDevice,callback) unless uuid?

  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice uuid, (error, device) =>
    return _getKey(device,callback)

    debug 'error', (JSON.stringify error)
    return callback error if error?


