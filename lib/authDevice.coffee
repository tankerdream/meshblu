_      = require 'lodash'
bcrypt = require 'bcrypt'
debug  = require('debug')('hyga:authDevice')

hyGaError = require('./models/hyGaError');

module.exports = (uuid, token, callback=(->), dependencies={}) ->
  Device = dependencies.Device ? require './models/device'
  return callback hyGaError(401,'No uuid') unless uuid? & token?

  device = new Device {uuid: uuid}, {config: dependencies.config}

  device.verifyToken token, (error, verified) =>

    debug 'verifyToken', error
    return callback error if error?
    return callback hyGaError(401,'Device not found') unless verified

    device.fetch (error, attributes) =>
      debug('fetch', error.stack) if error?
      return callback error if error?
      return callback hyGaError(401,'Unauthorized') unless device
      delete attributes.token
      callback null, attributes
