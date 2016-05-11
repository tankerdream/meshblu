/**
 * Created by lvjianyao on 16/3/10.
 */
var _               = require('lodash');
var getDevice       = require('./getDevice');
var s_securityImpl    = require('./s_getSecurityImpl');
var s_oldUpdateList = require('./s_oldUpdateList');

var hyGaError = require('./models/hyGaError');

var isBadArgument = function(data){

  if(typeof(data.list) == 'string'){
    data.list = [data.list]
  }

  if(!_.isArray(data.list)){
    return true;
  }

  var api = ['push','pull'];
  if(!_.includes(api,data.api)){
    return true;
  }

  var listName = [
    'sendWhitelist',
    'discoverWhitelist',
    'configureList',
    'sendBlacklist',
    'discoverBlacklist',
  ];

  if(!_.includes(listName,data.listName)){
    return true;
  }

  return _.some(data.list,function(uuid){
    if(typeof(uuid) !== 'string')
      return true;
  });

}

function handleUpdateList(fromDevice, data, callback){
  callback = callback || _.noop();

  data.uuid = data.uuid || fromDevice.uuid;

  if(isBadArgument(data)){
    return callback(hyGaError(400,'Bad arguments'));
  }

  getDevice(data.uuid, function(error, device){

    if(error) {
      return callback(error);
    }

    s_securityImpl.canConfigureList(fromDevice, device, data, function(error, permission) {

      if(!permission || error) {
        return callback(hyGaError(401,'Unauthorized'));
      }

      delete data.token;

      s_oldUpdateList(device.uuid, data, function(error, results){
        callback(error,results);
      });
    });
  });
}

module.exports = handleUpdateList;
