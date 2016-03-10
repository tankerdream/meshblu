var config = require('../config');
var messageIOEmitter = require('./createMessageIOEmitter')();

//向UUID的channel中广播topic为message的消息
function sendActivity(data){
  //TODO throttle
  if(config.broadcastActivity && data && data.ipAddress){
    //消息的发送参数：channel、topic、data
    //其实就是调用了('socket.io-emitter')('redis.client').in(config.uuid+'_bc').emit('message',data)
    messageIOEmitter(config.uuid + '_bc', 'message', data);
  }
}

module.exports = sendActivity;
