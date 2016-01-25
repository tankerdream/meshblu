/**
 * Created by lvjianyao on 15/12/13.
 */
var config = require('./../config');
var path = require('path');

if(config.mongo && config.mongo.databaseUrl){

  var mongojs = require('mongojs');
  var db = mongojs(config.mongo.databaseUrl);
  module.exports = {
    s_channels: db.collection('s_channels')
  };

} else {

  var Datastore = require('nedb');
  var s_channels = new Datastore({
    filename: path.join(__dirname, '/../s_channels.db'),
    autoload: true }
  );

  module.exports = {
    s_channels: s_channels
  };

}
