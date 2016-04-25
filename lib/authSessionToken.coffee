_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authDevice')

hyGaError = require('./models/hyGaError');

module.exports = (uuid, token, callback=(->), dependencies={}) ->
  Device = dependencies.Device ? require './models/device'
  return callback hyGaError(401,'No uuid'), null unless uuid?
  device = new Device {uuid: uuid}, {config: dependencies.config}

  device.verifySessionToken token, (error, verified) =>

    return callback null, true if verified
    return callback error if error?
    return callback hyGaError(401,'Unable to find valid device')
