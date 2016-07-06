var _      = require('lodash');
var moment = require('moment');
var config = require('./../config');
var devices = require('./database').devices;
var authDevice = require('./authDevice');
var oldUpdateDevice = require('./oldUpdateDevice');

var debug = require('debug')('hyga:s_updateSocketId');

module.exports = function(socket, callback) {
  
  var uuid = socket.uuid;
  delete socket.uuid;

  oldUpdateDevice(uuid, socket, function(error, device) {
    callback(error, device);
  })

};
