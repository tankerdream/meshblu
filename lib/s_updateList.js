/**
 * Created by lvjianyao on 16/3/10.
 */
var _               = require('lodash');
var getDevice       = require('./getDevice');
var s_securityImpl    = require('./s_getSecurityImpl');

var hyGaError = require('./models/hyGaError');
var debug = require('debug')('hyga:saveList');
var Device = require('./models/device')

var listName = [
  'whiteList',
  'configureList',
  'blackList'
];


function _handleUpdateList(fromDevice, message, callback){

  var uuid = message.uuid || fromDevice.uuid;


  if(!_.includes(listName, message.listName)){
    return callback(hyGaError(400, 'Invalid listName'));
  }

  if(_.some(message.list, function(uuid){
    return typeof(uuid) != 'string';
  })){
    return callback(hyGaError(400, 'Invalid list'));
  }

  getDevice(uuid, function(error, device){

    if(error) {
      return callback(error);
    }

    s_securityImpl.canConfigureList(fromDevice, device, message, function(error, permission) {

      debug('permission', permission)

      if(!permission || error) {
        return callback(hyGaError(401,'Unauthorized'));
      }
      device = new Device({uuid: uuid})
      return callback(null, device)

    });

  });
}

var pushList = function(fromDevice, message, callback){

  if(!_.isArray(message.list)){
    message.list = [message.list];
  }

  _handleUpdateList(fromDevice, message, function(error, device){

    if(error) {
      return callback(error);
    }

    device.pushList(message.listName, message.list, function(error){
      if(error) {
        return callback(error);
      }
      return callback(null);
    });
  });

};

var pullList = function(fromDevice, message, callback){

  var list = message.list;
  if(!_.isArray(list)){
    list = [list];
  }
  message.list = list;

  _handleUpdateList(fromDevice, message, function(error, device){

    if(error) {
      return callback(error);
    }

    device.pullList(message.listName, list, function(error){
      if(error) {
        return callback(error);
      }
      return callback(null);
    });
  });

};

module.exports.pushList = pushList;
module.exports.pullList = pullList;