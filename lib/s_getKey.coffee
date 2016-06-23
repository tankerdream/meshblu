_ = require 'lodash'
debug = require('debug')('hyga:getPublicKey')

s_securityImpl = require './s_getSecurityImpl'

hyGaError = require('./models/hyGaError');

_getKey = (device,callback) ->

  return callback hyGaError(404,'No Key') unless device.key?

  debug 'device', device
  callback null, device.key

module.exports = (fromDevice, params, callback=_.noop, dependencies={}) ->

  debug 'params', params
  return _getKey(fromDevice, callback) unless params.uuid?

  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice params.uuid, (error, check) =>
    return callback error if error?

    s_securityImpl.canDiscover fromDevice, check, params.sesToken, (error, permission)=>

      return callback hyGaError(401,'Unauthorized') if !permission || error

      return _getKey check, callback