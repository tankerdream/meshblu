var _               = require('lodash');
var getDevice       = require('./getDevice');
var logEvent        = require('./logEvent');
var s_securityImpl    = require('./s_getSecurityImpl');
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

    s_securityImpl.canConfigure(fromDevice, device, function(error, permission) {

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
