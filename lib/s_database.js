/**
 * Created by lvjianyao on 15/12/13.
 */
var config = require('./../config');
var path = require('path');

if(config.mongo && config.mongo.databaseUrl){

  var mongojs = require('mongojs');
  var db = mongojs(config.mongo.databaseUrl);
  module.exports = {
    users: db.collection('users')
  };

} else {

  var Datastore = require('nedb');
  var users = new Datastore({
    filename: path.join(__dirname, '/../users.db'),
    autoload: true }
  );

  module.exports = {
    users: users
  };
}
