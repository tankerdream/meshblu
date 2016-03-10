_  = require 'lodash'
debug = require('debug')('meshblu:oldUpdateDevice')
Device = require './models/device'

module.exports = (uuid, data, callback=_.noop, dependencies={})->
  device = new Device uuid: uuid, dependencies

  if data.api == 'push'
    device.pushList data.listName, data.list,(error)=>
      return callback error if error?
      device.fetch callback
  else
    device.pullList data.listName, data.list,(error)=>
      return callback error if error?
      device.fetch callback