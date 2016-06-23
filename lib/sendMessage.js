var _ = require('lodash');
var config = require('../config');
var getDevice = require('./getDevice');
var logEvent = require('./logEvent');
var sendYo = require('./sendYo');
var sendSms = require('./sendSms');
var securityImpl = require('./getSecurityImpl');
var sendActivity = require('./sendActivity');
var createActivity = require('./createActivity');
var sendPushNotification = require('./sendPushNotification');
var debug = require('debug')('meshblu:sendMessage');
var doMessageHooks = require('./doMessageHooks');
var doMessageForward = require('./doMessageForward');
var getSubscriptions = require('./getSubscriptions');
var logError = require('./logError');
var async = require('async');
var Benchmark = require('simple-benchmark');
var Publisher = require('./Publisher');
var publisher = new Publisher

var DEFAULT_QOS = 0;


var s_securityImpl = require('./s_getSecurityImpl');
var hyGaError = require('./models/hyGaError');

function publishActivity(topic, fromDevice, toDevice, data){
  if(fromDevice && fromDevice.ipAddress){
    sendActivity(createActivity(topic, fromDevice.ipAddress, fromDevice, toDevice, data));
  }
}

function cloneMessage(msg, device, fromUuid){
  if(typeof msg === 'object'){
    var clonedMsg = _.clone(msg);
    clonedMsg.devices = device; //strip other devices from message
    delete clonedMsg.protocol;
    delete clonedMsg.api;
    clonedMsg.fromUuid = msg.fromUuid; // add from device object to message for logging
    return clonedMsg;
  }

  return msg;
}


function MessageSender(socketEmitter, mqttEmitter, parentConnection){

  //建立与父连接的关系
  function forwardMessage(message){
    //存在父连接时执行
    if(parentConnection && message){
      try{
        message.originUuid = message.fromUuid;
        delete message.fromUuid;
        parentConnection.message(message);
      }catch(ex){
        logError(ex, 'error forwarding message');
      }
    }
  }

  function messageForward(toDevice, emitMsg, callback){
    var benchmark = new Benchmark({label: 'messageForward'});
    //如果目标设备没有配置meshblu，则返回回调
    if (!toDevice.meshblu) {
      return callback()
    }
    //如果配置了meshblu，则执行钩子操作
    doMessageHooks(toDevice, toDevice.meshblu.messageHooks, emitMsg, function(error) {
      doMessageForward(toDevice.meshblu.messageForward, emitMsg, toDevice.uuid, function(error, messages) {
        async.each(messages, function(msg, done){
          getDevice(msg.forwardTo, function(error, forwardDevice) {
            if(error) {
              logError(error);
              return done();
            }
            if(!forwardDevice) {
              logError('sendMessage.js: forwardDevice not found');
              return done();
            }
            sendMessage(forwardDevice.uuid, msg.message, msg.topic, toDevice.uuid, toDevice, [forwardDevice.uuid], done);
          });
        }, function(){
          debug(benchmark.toString());
          callback();
        });
      });
    });
  }

  //广播消息
  function broadcastMessage(data, topic, fromUuid, fromDevice, callback){

    //broadcasting should never require responses
    delete data.ack;

    publishActivity(topic, fromDevice, null, data);
    var logMsg = _.clone(data);
    logMsg.from = _.pick(_.clone(fromDevice), config.preservedDeviceProperties);
    logEvent(300, logMsg);

    async.parallel([
      //向源设备分别发送两个主题的消息消息
      async.apply(publisher.publish, 'broadcast', fromUuid, data),
      //否则源设备会收到两次信息
      //async.apply(publisher.publish, 'sent', fromUuid, data),
      //向目标设备发送消息
      //async.apply(sendStateFullBroadcasts, fromUuid, data)
    ], function(err){
      return callback(err)
    });
  };

  var sendStateFullBroadcasts = function(fromUuid, data, callback){
    getSubscriptions(fromUuid, 'broadcast', function(error, toUuids){
      if(error) {
        logError(error);
        return callback();
      }
      async.each(toUuids, function(uuid, done){
        async.parallel([
          async.apply(publisher.publish, 'broadcast', uuid, data),
          async.apply(handleForwardMessage, uuid, data)
        ], done);
      }, callback);
    });
  }

  //根据uuid推送信息
  var handleForwardMessage = function(uuid, data, callback) {
    //根据UUID验证设备有效性，若有效则返回设备
    getDevice(uuid, function(error, device){
      if(error) {
        logError(error);
        return callback();
      }
      messageForward(device, data, callback);
    });
  }

  //向多个设备发送多条信息
  var sendMessages = function(uuids, data, sesToken, topic, fromUuid, fromDevice, toDevices, callback){
    async.each(uuids, function(uuid, done){
      sendMessage(uuid, data, sesToken, topic, fromUuid, fromDevice, data.devices, done);
    }, callback);
  };

  var sendMessage = function(uuid, data, sesToken, topic, fromUuid, fromDevice, toDevices, callback){
    var benchmark = new Benchmark({label: 'sendMessage'});

    var toDeviceProp = uuid;
    //
    if (uuid.length <= 0){
      return callback();
    }

    //将设备列表转换为数组,toDevices可能是字符串形式,不能直接使用
    var uuidArray = uuid.split('/');
    if(uuidArray.length > 1){
      uuid = uuidArray.shift();
      toDeviceProp = uuidArray.join('/');
    }

    //根据UUID验证设备有效性，若有效则返回设备
    getDevice(uuid, function(error, check) {

      //check是从服务器数据库中取得的对应设备
      var clonedMsg = cloneMessage(data, toDeviceProp, fromUuid);

      if(error){
        clonedMsg.UNAUTHORIZED=true; //for logging
        forwardMessage(clonedMsg);
        return callback(error);
      }
      

      //验证发送消息的安全性
      s_securityImpl.canSend(fromDevice, check, sesToken, function(error, permission){

        //permission为真则可以发送
        publishActivity(topic, fromDevice, check, data);
        var emitMsg = clonedMsg;

        if(error)
          return callback(error);

        if(!permission){
          clonedMsg.UNAUTHORIZED=true; //for logging
          forwardMessage(clonedMsg);
          return callback(hyGaError(401,'No permission',{uuid:check.uuid}));
        }

        // Added to preserve to devices in message
        emitMsg.devices = toDevices;

        if(check.payloadOnly){
          //如果设备只接受核心内容
          emitMsg = clonedMsg.payload;
        }

        //var logMsg = _.clone(clonedMsg);
        //logMsg.toUuid = check.uuid;
        //logMsg.to = _.pick(check, config.preservedDeviceProperties);
        //logMsg.from = _.pick(fromDevice, config.preservedDeviceProperties);
        //logEvent(300, logMsg);

        debug(benchmark.toString());

        async.parallel([
          //async.apply(publisher.publish, 'sent', fromDevice.uuid, data),
          async.apply(publisher.publish, 'received', uuid, data),
          async.apply(messageForward, check, emitMsg)
        ], callback);
      });
    });
  };

  MessageSender.prototype.hyga_sendMessage = function(fromDevice, data, topic, callback){
    var benchmark = new Benchmark({label: 'curried-function'});
    data = _.clone(data);
    //TODO 去掉topic
    //消息体中没有devices则默认发送消息给频道
    var uuids = data.uuids;
    delete data.uuids;

    if(!uuids) {
      uuids = fromDevice.owner;
    }

    if( typeof uuids === 'string' ) {
      uuids = [ uuids ];
    }

    var sesToken = data.sesToken;
    delete data.sesToken;

    //cant ack to multiple devices
    if(uuids.length > 1){
      delete data.ack;
      //使用token发送消息只能有一个目标设备
      token = null;
    }


    topic = topic || 'message';

    var fromUuid;
    if(fromDevice){
      fromUuid = fromDevice.uuid;
    }

    if(fromUuid){
      data.fromUuid = fromUuid;
    }

    //fromDevice主要是带有uuid的对象
    debug(benchmark.toString());

    return sendMessages(uuids, data, sesToken, topic, fromUuid, fromDevice, data.devices, callback);

  };

  MessageSender.prototype.hyga_broadcast = function(fromDevice, data, callback){
    var benchmark = new Benchmark({label: 'curried-function broadcast'});
    data = _.clone(data);

    delete data.uuids;
    delete data.sesToken;
    delete data.ack;

    var fromUuid;
    if(fromDevice){
      fromUuid = fromDevice.uuid;
    }

    if(fromUuid){
      data.fromUuid = fromUuid;
    }

    //fromDevice主要是带有uuid的对象
    debug(benchmark.toString());

    //判断是否是广播消息
    return broadcastMessage(data, null, fromUuid, fromDevice, callback);

  };

}

module.exports = MessageSender;