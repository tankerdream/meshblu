'use strict';
var _ = require('lodash');
var coap       = require('coap');
var throttles = require('./getThrottles');
var MessageSender = require('./sendMessage');
var setupCoapRoutes = require('./setupCoapRoutes');
var sendActivity = require('./sendActivity');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var logError = require('./logError');

var coapServer = function(config, parentConnection){
  //得到一个消息发送函数
  var socketEmitter = createMessageIOEmitter();

  var  messageSender= new MessageSender(socketEmitter, _.noop, parentConnection);
  var sendMessage = messageSender.hyga_sendMessage;
  var broadcast = messageSender.hyga_broadcast;

  if(parentConnection){
    parentConnection.on('message', function(data, fn){
      if(data){
        var devices = data.devices;
        if (!_.isArray(devices)) {
          devices = [devices];
        }
        _.each(devices, function(device) {
          if(device !== config.parentConnection.uuid){
            //fn是topic
            sendMessage({uuid: data.fromUuid}, data, fn);
          }
        });
      }
    });
  }

  var coapRouter = require('./coapRouter'),
      coapServer = coap.createServer(),
      coapConfig = config.coap || {};


  function emitToClient(topic, device, msg){
    socketEmitter(device.uuid, topic, msg);
  }

  var skynet = {
    sendMessage: sendMessage,
    broadcast: broadcast,
    sendActivity: sendActivity,
    throttles: throttles,
    emitToClient: emitToClient
  };

  //实例化coapRouter，为Router中的GET、POST、DELETE等方法提供具体实现
  setupCoapRoutes(coapRouter, skynet);

  coapServer.on('request', coapRouter.process);
  coapServer.on('error', logError);

  var coapPort = coapConfig.port || 5683;
  var coapHost = coapConfig.host || '127.0.0.1';

  coapServer.listen(coapPort, function () {
    console.log('CoAP listening at coap://' + coapHost + ':' + coapPort);
  });
}

module.exports = coapServer;
