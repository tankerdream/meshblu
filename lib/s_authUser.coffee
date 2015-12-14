_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authDevice')

module.exports = (uuid, token, callback=(->), dependencies={}) ->
  User = dependencies.User ? require './models/user'
  user = new User {uuid: uuid}, {config: dependencies.config}
  user.verifyPsd token, (error, verified) =>
    debug('verifyUserPsd', error.stack) if error?

    return callback error if error?
    return callback new Error('No permission to add device') unless verified
    user.fetch (error, attributes) =>
      debug('fetch user', error.stack) if error?
      return callback error if error?
      callback null, attributes