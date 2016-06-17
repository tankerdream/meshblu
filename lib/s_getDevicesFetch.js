/**
 * Created by lvjianyao on 16/3/10.
 */
var _ = require('lodash');
var debug = require('debug')('hyga:s_getDevicesFetch');

var queryFetch = function(fromUuid, owner, query){
  var queryFetch = {
    owner: owner
  }
  delete query.owner;
  for (var param in query) {
    queryFetch[param] = query[param];
  }

  queryFetch.blackList = {$ne: fromUuid};

  return queryFetch;
}

var selfChannelFetch = function(fromUuid, owner, query){

  var selfFetch = queryFetch(fromUuid, owner, query);

  selfFetch['$or'] = [
    {authority: {$exists: false}},
    {authority: {$ne: 'private'}},
    {
      authority: 'private',
      whiteList: fromUuid
    }
  ]

  debug('selfFetch', selfFetch);
  return selfFetch;

}

var otherChannelFetch = function(fromUuid, owner, query){

  var otherFetch = queryFetch(fromUuid, owner, query);
  otherFetch['$or'] = [
    {authority: 'public'},
    {
      authority: { $ne: 'public' },
      whiteList: fromUuid
    }
  ]

  return otherFetch;

}

module.exports = function (fromDevice,fromDeviceAliases,query){

  var fetch = {};

  if(query.owner == null){
    fetch = selfChannelFetch(fromDevice.uuid, fromDevice.owner, query);
  }else if(query.owner == fromDevice.uuid){
    fetch = queryFetch(fromUuid.uuid, owner, query);
  }else{
    fetch = otherChannelFetch(fromDevice.uuid, query.owner, query);
  }

  var filter = {
    _id:true
  }
  
  debug('getDevices start query',fetch);

  return {fetch:fetch,filter:filter}

}