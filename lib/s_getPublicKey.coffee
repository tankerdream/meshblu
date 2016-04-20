_ = require 'lodash'
debug = require('debug')('hyga:getPublicKey')

hyGaError = require('./models/hyGaError');

_getKey = (device,callback) ->

  return callback hyGaError(404,'No publicKey'), null unless device?.publicKey

  debug 'device', device
  name = device.publicName || 'publicKey'
  publicKey = device?.publicKey
  callback null, {"#{name}": publicKey}

module.exports = (fromDevice, uuid, callback=_.noop, dependencies={}) ->

  return _getKey(fromDevice,callback) unless uuid?

  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice uuid, (error, device) =>
    return callback error if error?

    return _getKey(device,callback)



