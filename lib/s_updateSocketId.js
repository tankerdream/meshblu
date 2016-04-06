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
  token = socket.token;
  delete socket['token'];

  var auto_set_online = socket.auto_set_online !== false;
  delete socket.auto_set_online;
  var unauthorizedResponse = hyGaError(401,'Unauthorized');

  if (_.isUndefined(socket.online) && auto_set_online) {
    socket.online = true;
  }

  oldUpdateDevice(uuid, socket, function(error, device) {

    if(error) {
      return callback(unauthorizedResponse);
    }
    callback({uuid: uuid, code: 201, device: device});

  })

};
