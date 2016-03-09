_ = require 'lodash'
async = require 'async'
hyGaError = require './models/hyGaError';

sanitizeData = (data) ->

  #TODO key是pm2.5时存储错误
  tmpData = {}
  tmpData.key = data.key
  tmpData.val = data.val
  tmpData.uuid = @fromUuid
  tmpData.timestamp = @moment(data.timestamp).toISOString() || moment().toISOString()

  return tmpData

module.exports = (sendMessage, fromDevice, params, callback=_.noop, dependencies={}) ->

  @moment = dependencies.moment ? require 'moment'
  dataDB = dependencies.dataDB ? require('./database').data
  @fromUuid = fromDevice.uuid

  return callback hyGaError(400,'No data') unless params?.data?

  return callback hyGaError(400,"Invalid data") unless _.every params.data,((data)=>data.val? && data.key?)

  @dataArray = _.map params.data,sanitizeData

  async.each @dataArray,(data,done) =>

    key = data.key
    delete data.key

    dataDB.update {'channelUuid':fromDevice.owner},{$addToSet:{"#{key}":data}},(error)->
      done error if error?
      done null
  ,callback