var _      = require('lodash');
var moment = require('moment');
var config = require('./../config');
var devices = require('./database').devices;
var authDevice = require('./authDevice');
var oldUpdateDevice = require('./oldUpdateDevice');

var hyGaError = require('./models/hyGaError');
var debug = require('debug')('hyga:s_updateSocketId');

module.exports = function(socket, callback) {
  var uuid, token;

  socket = _.clone(socket);

  uuid = socket.uuid;
  delete socket['uuid'];

  var unauthorizedResponse = hyGaError(401,'Unauthorized');

  oldUpdateDevice(uuid, socket, function(error, device) {

    if(error) {
      return callback(unauthorizedResponse);
    }
    callback({uuid: uuid, code: 201, device: device});

  })

};
