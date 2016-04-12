var logError = require('./logError');
//包装发送给客户端的mqtt消息
function wrapMqttMessage(message){
  return JSON.stringify(message);
  //var topic = message.topic || 'message';
  //var data = message.payload || {};
  //var _request = message._request;
  //try{
  //  if(message.topic === 'tb'){
  //    //TODO topic为tb?
  //    if(typeof message !== 'string'){
  //      return JSON.stringify(message);
  //    }
  //    return data;
  //  }else{
  //    return JSON.stringify(message);
  //    //return JSON.stringify({data: message, _request: _request});
  //  }
  //}catch(ex){
  //  logError(ex, 'error wrapping mqtt message', ex.stack);
  //}
}

module.exports = wrapMqttMessage;
