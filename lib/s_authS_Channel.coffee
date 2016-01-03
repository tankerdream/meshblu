_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authS_Channel')

module.exports = (uuid, token, callback=(->), dependencies={}) ->
  S_Channel = dependencies.S_Channel ? require './models/s_channel'
  s_channel = new S_Channel {uuid: uuid}, {config: dependencies.config}
  s_channel.verifyToken token, (error, verified) =>
    debug('verifyS_ChannelToken', error.stack) if error?

    return callback error if error?
    return callback new Error('No permission to add device') unless verified
    s_channel.fetch (error, attributes) =>
      debug('fetch s_channel', error.stack) if error?
      return callback error if error?
      callback null, attributes