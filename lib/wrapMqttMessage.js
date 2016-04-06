var logError = require('./logError');
//包装发送给客户端的mqtt消息
function wrapMqttMessage(message){
  var topic = message.topic || 'message';
  var data = message.payload || {};
  var _request = message._request;
  try{
    if(topic === 'tb'){
      if(typeof data !== 'string'){
        return JSON.stringify(data);
      }
      return data;
    }else{
      return JSON.stringify({topic: topic, data: data, _request: _request});
    }
  }catch(ex){
    logError(ex, 'error wrapping mqtt message', ex.stack);
  }
}

module.exports = wrapMqttMessage;
