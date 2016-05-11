_ = require 'lodash'
authDevice = require './authDevice'
getDevice = require './getDevice'
config = require '../config'
MessageIOClient = require './messageIOClient'
{Readable} = require 'stream'
securityImpl = require './getSecurityImpl'
debug = require('debug')('meshblu:subscribeAndForward')

s_securityImpl = require './s_getSecurityImpl'
hyGaError = require './models/hyGaError'

connectIO = (response) ->
  msgIOClient = new MessageIOClient()

  msgIOClient.on 'message', (message) ->
    debug 'onMessage', message

    respData = {}
    respData.t = 'msg'
    respData.p = message

    response.write(JSON.stringify(respData))

  response.write(JSON.stringify({s:true}))

  response.on 'close', ->
    msgIOClient.close()

  return msgIOClient

connectBroadcastIO = (response) ->
  msgIOClient = new MessageIOClient()

  msgIOClient.on 'broadcast', (message) ->
    debug 'onMessage', 'broadcast', message

    respData = {}
    respData.t = 'brd'
    respData.p = message

    response.write(JSON.stringify(respData))

  response.write(JSON.stringify({s:true}))

  response.on 'close', ->
    msgIOClient.close()

  return msgIOClient

class SubForwarder

  subBroadcast : (askingDevice, response, uuids) ->
    messageIOClient = connectBroadcastIO(response)
    messageIOClient.subBroadcast askingDevice, uuids


  subscribe : (askingDevice, response, uuid) ->
    uuid = uuid || askingDevice.uuid

    getDevice uuid, (error, subscribedDevice) ->

      return response.json(hyGaError(401,'Unauthorized')) if error

      s_securityImpl.canSend askingDevice, subscribedDevice, null, (error, permission) ->

        return response.json(hyGaError(401,'Unauthorized')) if error

        return response.json(hyGaError(401,'Unauthorized')) if !permission

        authorizedSubscriptionTypes = ['received', 'config', 'data']

        messageIOClient = connectIO(response)
        messageIOClient.subscribe uuid, authorizedSubscriptionTypes


module.exports = SubForwarder
