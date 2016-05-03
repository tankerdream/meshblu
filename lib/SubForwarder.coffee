_ = require 'lodash'
authDevice = require './authDevice'
getDevice = require './getDevice'
config = require '../config'
MessageIOClient = require './messageIOClient'
{Readable} = require 'stream'
securityImpl = require './getSecurityImpl'
debug = require('debug')('meshblu:subscribeAndForward')

s_securityImpl = require './s_getSecurityImpl'

subscribeAndForwardWithToken = (response, uuid, token, requestedSubscriptionTypes, payloadOnly, topics) ->
  authDevice uuid, token, (error, authedDevice) ->
    messageIOClient = connectIO(response, 'message', payloadOnly)
    messageIOClient.subscribe uuid, requestedSubscriptionTypes, topics

connectIO = (response, type, payloadOnly=false) ->
  msgIOClient = new MessageIOClient()

  msgIOClient.on type, (message) ->
    debug 'onMessage', type, message
    if payloadOnly
      message = message?.payload

    respData = {}
    respData.type = type
    respData.payload = message

    response.write(JSON.stringify(respData))

  response.write(JSON.stringify({s:true}))

  response.on 'close', ->
    msgIOClient.close()

  return msgIOClient

class SubForwarder

  subBroadcast : (askingDevice, response, uuid) ->
    messageIOClient = connectIO(response, 'broadcast', false)
    messageIOClient.subBroadcast askingDevice, uuid


  subscribe : (askingDevice, response, uuid, token, requestedSubscriptionTypes) ->
    uuid = uuid || askingDevice.uuid
#    if token
#      return subscribeAndForwardWithToken(response, uuid, token, requestedSubscriptionTypes)

    getDevice uuid, (error, subscribedDevice) ->
      if error
        return response.json(error: 'unauthorized')
      s_securityImpl.canSend askingDevice, subscribedDevice, null, (error, permission) ->

        return response.json(error: 'unauthorized') if error

        return response.json(error: 'unauthorized') if !permission

        authorizedSubscriptionTypes = ['received', 'config', 'data']

        messageIOClient = connectIO(response, 'message')
        messageIOClient.subscribe uuid, authorizedSubscriptionTypes


module.exports = SubForwarder
