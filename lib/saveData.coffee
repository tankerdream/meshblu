_ = require 'lodash'
async = require 'async'
hyGaError = require './models/hyGaError';
debug = require('debug')('hyga:saveData')

sanitizeData = (data) ->

  #TODO key是pm2.5时存储错误
  tmpData = {}

  delete data._id
  delete data._uuid
  delete data._timestamp

  tmpData = data
  tmpData._uuid = tmpData.uuid || @fromUuid
  tmpData._timestamp = new Date()

  return tmpData

module.exports = (fromDevice, params, callback=_.noop, dependencies={}) ->

  getCollection = dependencies.dataDB ? require('./database').getCollection
  @fromUuid = fromDevice.uuid

  dataDB = getCollection(fromDevice.owner)

  return callback hyGaError(400,'No data') unless params

  params = [params] if not _.isArray(params)

  @dataArray = _.map params, sanitizeData

  async.each @dataArray,(data,done) =>

    debug 'data', data
    dataDB.insert data,(error)->
      return done error if error?
      return done null

  ,callback