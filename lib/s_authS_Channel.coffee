_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('hyga:authS_Channel')

hyGaError     = require('./models/hyGaError');

module.exports = (uuid, dmToken, callback=(->), dependencies={}) ->

  debug 'uuid', uuid
  debug 'token', dmToken

  S_Channel = dependencies.S_Channel ? require './models/s_channel'
  s_channel = new S_Channel {uuid: uuid}, {config: dependencies.config}
  s_channel.verifyToken 'reg', dmToken, (error, verified) =>
    debug 'verified',verified
    debug('verifyS_ChannelToken', error.stack) if error?

    return callback error if error?
    return callback hyGaError(401, 'No permission to add device') unless verified
    s_channel.fetch (error, attributes) =>

      debug('fetch s_channel', error.stack) if error?
      debug 'attributes',attributes

      return callback error if error?
      callback null, attributes