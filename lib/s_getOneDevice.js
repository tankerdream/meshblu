/**
 * Created by lvjianyao on 16/3/10.
 */
var _ = require('lodash');
var async = require('async');
var debug = require('debug')('hyga:s_getOneDevice');
var config = require('./../config');
var devices = require('./database').devices;
var logEvent = require('./logEvent');
var UuidAliasResolver = require('../src/uuid-alias-resolver');
var uuidAliasResolver = new UuidAliasResolver({}, {aliasServerUri: config.aliasServer.uri});

var hyGaError = require('./models/hyGaError');
var s_getDevicesFetch = require('./s_getDevicesFetch');

function processResults(error, result, callback) {

  if (error) {
    return callback(hyGaError(404,'Device not found'));
  }

  if (result === null){
    return callback(null, null);
  }

  callback(null, result._id);

}

module.exports = function(fromDevice, query, callback) {

  if (query.uuid && query.token) {
    return checkToken(query.uuid, query.token, callback);
  }
  
  var fromDeviceUuid = fromDevice.uuid;

  uuidAliasResolver.reverseLookup(fromDeviceUuid, function(error, fromDeviceAliases) {
    fromDeviceAliases = fromDeviceAliases || [];
    fromDeviceAliases.push(fromDeviceUuid);

    var mongoCmd = s_getDevicesFetch(fromDevice, fromDeviceAliases, query)

    devices.findOne(mongoCmd.fetch, mongoCmd.filter,function(error, device) {

      debug('gotDevices mongo');
      processResults(error, device, callback);

    });

  });

};
