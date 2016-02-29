_ = require 'lodash'
async = require 'async'

debug = require('debug')('hyga:Publisher')

class Publisher
  constructor: (options={}, dependencies={}) ->
    {@namespace} = options
    {@client,@devices,@subscriptions} = dependencies
    @namespace ?= 'meshblu'
    {createClient} = require './redis'
    @client ?= _.bindAll createClient()
    PublishForwarder = require '../src/publish-forwarder'
    @publishForwarder = new PublishForwarder {publisher: @}, {@devices, @subscriptions}

  publish: (type, uuid, message, callback) =>

    channel = "#{@namespace}:#{type}:#{uuid}"

    debug 'channel', channel

    return callback new Error 'Invalid message' unless message?
    async.series [
      async.apply @client.publish, channel, JSON.stringify(message)
      async.apply @publishForwarder.forward, {type, uuid, message}
    ], callback


module.exports = Publisher
