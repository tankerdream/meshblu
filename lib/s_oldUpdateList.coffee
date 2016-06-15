_  = require 'lodash'
debug = require('debug')('meshblu:oldUpdateDevice')
Device = require './models/device'

pushList = (uuid, data, callback=_.noop)->
  device = new Device uuid: uuid
  device.pushList data.listName, data.list,(error)=>
      return callback error if error?
      callback null

pullList = (uuid, data, callback=_.noop)->
  device = new Device uuid: uuid
  device.pullList data.listName, data.list,(error)=>
      return callback error if error?
      callback null

module.exports.pushList = pushList()
module.exports.pullList = pullList()