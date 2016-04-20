/**
 * Created by lvjianyao on 16/3/10.
 */
var _ = require('lodash');
var debug = require('debug')('hyga:s_getDevicesFetch');

module.exports = function (fromDevice,fromDeviceAliases,query){

  var fetch = {};
  // Loop through parameters to update device
  for (var param in query) {
    fetch[param] = query[param];
    if (query[param] === 'null' || query[param] === ''){
      fetch[param] = { "$exists" : false };
    }
  }
  if (_.isString(query.online)){
    fetch.online = query.online === "true";
  }

  delete fetch.token;

  //var filter = {
  //  socketid: false,
  //  _id: false,
  //  token: false,
  //  discoverWhitelist: false,
  //  discoverBlacklist: false,
  //  sendWhitelist: false,
  //  sendBlacklist: false,
  //  configureWhitelist: false,
  //  configureBlacklist: false,
  //  meshblu: false
  //}

  var filter = {
    uuid: true,
    _id:false
  }

  //TODO Blacklist
  var canDiscover = [
    {
      uuid: fromDevice.uuid
    },
    {
      discoverWhitelist: { $in: fromDeviceAliases }
    },
    {
      discoverWhitelist: {
        $exists: false
      }
    },
    {
      owner: { $in: fromDeviceAliases }
    }
  ]

  var publicFetch = {
    authority: 'public'
  }

  var protectedFetch = {
    authority: {
      $exists: false
    },
    $or: [
      {
        owner: fromDevice.owner
      },
      {
        $or: canDiscover
      }
    ]
  }

  var privateFetch = {
    authority: 'private',
    $or: canDiscover
  }

  fetch['$or'] = [protectedFetch,privateFetch,publicFetch]

  debug('getDevices start query',fetch);

  return {fetch:fetch,filter:filter}

}