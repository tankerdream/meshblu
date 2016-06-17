/**
 * Created by lvjianyao on 16/3/10.
 */
var _               = require('lodash');
var getDevice       = require('./getDevice');
var s_securityImpl    = require('./s_getSecurityImpl');

var hyGaError = require('./models/hyGaError');
var debug = require('debug')('hyga:saveList');
var Device = require('./models/device')

function _handleUpdateList(fromDevice, message, callback){

  var uuid = message.uuid || fromDevice.uuid;

  getDevice(uuid, function(error, device){

    if(error) {
      return callback(error);
    }

    s_securityImpl.canConfigure(fromDevice, device, message.sesToken, function(error, permission, selfOrOwner) {

      debug('permission', permission)

      if(error || !permission) {
        return callback(error);
      }

      debug('selfOrOwner', selfOrOwner);

      var list = [];

      if(selfOrOwner){

        list = message.list
        if(!_.isArray(list)){
          list = [list];
        }
        if(_.some(list, function(uuid){
            return typeof(uuid) != 'string';
          })){
          return callback(hyGaError(400, 'Invalid list'));
        }

      }else{
        list = [fromDevice.uuid]
      }

      device = new Device({uuid: uuid});
      return callback(null, list, device);

    });

  });
}

function _processResults(error, callback) {

  if (error) {
    callback(hyGaError(505,'Mongo error', error.message));
  }
  
  return callback();

}

var pushWhiteList = function(fromDevice, message, callback){

  _handleUpdateList(fromDevice, message, function(error, list, device){

    if(error) {
      return callback(error);
    }

    device.pushList('whiteList', list, function(error){
      _processResults(error, callback);
    });
  });

};

var pullWhiteList = function(fromDevice, message, callback){

  _handleUpdateList(fromDevice, message, function(error, list, device){

    if(error) {
      return callback(error);
    }

    device.pullList('whiteList', list, function(error){
      _processResults(error, callback);
    });
  });

};

var pushBlackList = function(fromDevice, message, callback){

  delete message.sesToken

  _handleUpdateList(fromDevice, message, function(error, list, device){

    if(error) {
      return callback(error);
    }

    device.pushList('blackList', list, function(error){
      _processResults(error, callback);
    });
  });

};

var pullBlackList = function(fromDevice, message, callback){
  
  delete message.sesToken

  _handleUpdateList(fromDevice, message, function(error, list, device){

    if(error) {
      return callback(error);
    }

    device.pullList('blackList', list, function(error){
      _processResults(error, callback);
    });
  });

};

module.exports.pushWhiteList = pushWhiteList;
module.exports.pullWhiteList = pullWhiteList;
module.exports.pushBlackList = pushBlackList;
module.exports.pullBlackList = pullBlackList;