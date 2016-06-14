var config = require('./../config');
var path = require('path');

var mongojs = require('mongojs');
var db = mongojs(config.mongo.databaseUrl);

var getCollection = function (channelUuid){
  return db.collection(channelUuid);
}

module.exports = {
  devices: db.collection('devices'),
  rmdevices: db.collection('rmdevices'),
  events: db.collection('events'),
  data: db.collection('data'),
  subscriptions: db.collection('subscriptions'),
  getCollection:getCollection
};

db.on('error', function (err) {
  if (/ECONNREFUSED/.test(err.message) ||
   /no primary server available/.test(err.message)) {
    console.error('FATAL: database error', err);
    process.exit(1);
  }
})