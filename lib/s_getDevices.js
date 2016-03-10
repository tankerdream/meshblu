/**
 * Created by lvjianyao on 16/3/9.
 */
var _ = require('lodash');
var async = require('async');
var debug = require('debug')('hyga:s_getDevices');
var config = require('./../config');
var devices = require('./database').devices;
var logEvent = require('./logEvent');
var authDevice = require('./authDevice');
var UuidAliasResolver = require('../src/uuid-alias-resolver');
var uuidAliasResolver = new UuidAliasResolver({}, {aliasServerUri: config.aliasServer.uri});

var hyGaError = require('./models/hyGaError');
var s_getDevicesFetch = require('./s_getDevicesFetch');

function checkToken(uuid, token, callback) {
  authDevice(uuid, token, function(error, result) {
    if (error || !result) {
      return callback(error);
    }
    callback(null, {devices: [result]});
  });
}

function processResults(error, results, callback) {
  if (error || results.length === 0) {
    return callback(hyGaError(404,'Devices not found'));
  }

  logEvent(403, {devices: results});
  callback(null, {devices: results});
}

module.exports = function(fromDevice, query, callback) {

  if (query.uuid && query.token) {
    return checkToken(query.uuid, query.token, callback);
  }

  var fromDeviceUuid = fromDevice.uuid;

  uuidAliasResolver.reverseLookup(fromDeviceUuid, function(error, fromDeviceAliases) {
    fromDeviceAliases = fromDeviceAliases || [];
    fromDeviceAliases.push(fromDeviceUuid);

    var mongoCmd = s_getDevicesFetch(fromDevice,fromDeviceAliases,query)

    devices.find(mongoCmd.fetch, mongoCmd.filter).maxTimeMS(10000).limit(1000).sort({ _id: -1 }, function(err, devices) {

      debug('gotDevices mongo');
      processResults(err, devices, callback);

    });

  });
};
