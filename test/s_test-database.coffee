async = require 'async'
USE_MONGO = process.env.USE_MONGO == 'true'

console.log "======================================================"
console.log "  Show using #{if USE_MONGO then 'mongo' else 'nedb'}"
console.log "======================================================"

if USE_MONGO
  mongojs = require 'mongojs'
  MONGO_DATABASE = mongojs 'meshblu-test', ['s_channels']

class s_TestDatabase
  @createNedbCollection: (collection, callback=->) =>
    Datastore = require 'nedb'
    datastore = new Datastore
      inMemoryOnly: true
      autoload: true
      onload: => callback null, datastore

  @open: (callback=->) =>
    if USE_MONGO
      async.parallel [
        (cb=->) => MONGO_DATABASE.users.remove cb
      ], (error) => callback error, MONGO_DATABASE
    else
      async.parallel
        s_channels: (cb=->) => @createNedbCollection 's_channels', cb
      , callback

module.exports = s_TestDatabase
