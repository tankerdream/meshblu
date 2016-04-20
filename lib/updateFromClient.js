var _               = require('lodash');
var getDevice       = require('./getDevice');
var logEvent        = require('./logEvent');
var securityImpl    = require('./getSecurityImpl');
var oldUpdateDevice = require('./oldUpdateDevice');

var hyGaError = require('./models/hyGaError');

function handleUpdate(fromDevice, data, callback){
  callback = callback || function(){};

  data.uuid = data.uuid || fromDevice.uuid;
  getDevice(data.uuid, function(error, device){
    if(error) {
      callback(error);
      return;
    }

    securityImpl.canConfigure(fromDevice, device, data, function(error, permission) {

      if(!permission || error) {
        return callback(hyGaError(401,'Unauthorized'));
      }

      delete data.token;

      oldUpdateDevice(device.uuid, data, function(error, results){
        callback(error, results);
      });
    });
  });
}

module.exports = handleUpdate;
