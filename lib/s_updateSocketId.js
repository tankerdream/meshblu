var _      = require('lodash');
var moment = require('moment');
var config = require('./../config');
var devices = require('./database').devices;
var authDevice = require('./authDevice');
var oldUpdateDevice = require('./oldUpdateDevice');

var hyGaError = require('./models/hyGaError');
var debug = require('debug')('hyga:s_updateSocketId');

module.exports = function(socket, callback) {

  socket = _.clone(socket);

  var uuid = socket.uuid;
  delete socket.uuid;

  oldUpdateDevice(uuid, socket, function(error, device) {
    callback(error, device);
    // if(error){
    //   return callback(hyGaError(401,'Unauthorized'));
    // }
    // return callback(null, {code: 201, device: device});
  })

};
