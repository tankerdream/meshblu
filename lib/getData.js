/**
 * Created by lvjianyao on 16/3/12.
 */
var moment = require('moment');
var config = require('./../config');

var data = require('./database').data;
var events = require('./database').events;
var logEvent = require('./logEvent');

var hyGaError = require('./models/hyGaError');

//从mongodb的events中获取数据
module.exports = function(req, fromDevice, callback) {

  var key = req.key;

  if(!key){
    return callback(hyGaError(400,'No key'));
  }

  var channelUuid = fromDevice.owner;
  var start = req.query.start; // time to start from
  var finish = req.query.finish; // time to end
  var limit = req.query.limit; // 0 bypasses the limit
  var stream = req.query.stream;

  var query = {
    'channelUuid':channelUuid
  }

  // set a default limit
  limit = parseInt(limit || 10);

  if (start) {
    start = moment(start).toISOString();
    query[key]={};
    //query[key]['val']={"$gte":40};
    query[key][key+'.timestamp'] = {"$gte": start};
  }

  if (finish) {
    finish = moment(finish).toISOString();
    query['timestamp'] = query['timestamp'] || {};
    query['timestamp']['$lte'] = finish;
  }

  var filter = {_id:false}
  filter[key] = true;

  if(stream){

    query["eventCode"] = 700; // data api eventcode

    var newTimestamp = new Date().getTime();
    query["timestamp"] = { '$gte' : moment(newTimestamp).toISOString()}
    logEvent(701, query);
    var cursor = events.find(query, {}, {tailable:true, timeout:false});
    return cursor;

  } else {
    data.find(query, filter).limit(limit).sort({ _id: -1 }, function(err, eventdata) {
      if(err) {
        return callback(err);
      }

      logEvent(701, query);
      callback({"data": eventdata});
    });
  }

};
