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

function processResults(error, results, callback) {

  if (error) {
    return callback(hyGaError(404,'Mongo error',error.message));
  }

  if (results.length === 0){
    return callback(null, null);
  }

  var mapResults = _.map(results, '_id');

  return callback(null, mapResults);

}

module.exports = function(fromDevice, query, callback) {

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
