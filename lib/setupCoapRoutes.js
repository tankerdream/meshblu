var _ = require('lodash');
var JSONStream = require('JSONStream');

var debug = require('debug')('meshblu:setupCoapRoutes');
var whoAmI = require('./whoAmI');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var register = require('./register');
var getEvents = require('./getEvents');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var resetToken = require('./resetToken');
var securityImpl = require('./getSecurityImpl');
var createActivity = require('./createActivity');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');
var createReadStream = require('./createReadStream');
var generateAndStoreToken = require('./generateAndStoreToken');
var subscribeAndForward = require('./subscribeAndForward');
var logError = require('./logError');

var saveDataIfAuthorized = require('./saveDataIfAuthorized');
var saveKey = require('./saveKey');
var saveData = require('./saveData');

var s_register = require('./s_register');
var s_unregister = require('./s_unregister');
var s_getKey = require('./s_getPublicKey');
var s_getOneDevice = require('./s_getOneDevice');
var s_getDevices = require('./s_getDevices');
var hyGaError = require('./models/hyGaError');
var s_updateList = require('./s_saveListIfAuthorized');
var getToken = require('./s_generateAndStoreToken');
var SubForwarder = require('./SubForwarder');

function getActivity(topic, req, device, toDevice){
  var ip = req.rsinfo.address;
  return createActivity(topic, ip, device, toDevice);
}

//psuedo middleware
//验证请求的token是否正确,正确则返回设备
function authorizeRequest(req, callback){
  var uuid = _.find(req.options, {name:'98'});
  var token = _.find(req.options, {name:'99'});
  if (uuid && uuid.value) {
    uuid = uuid.value.toString();
  }
  if (token && token.value) {
    token = token.value.toString();
  }

  debug('authorizeRequest', uuid, token);

  authDevice(uuid, token, function (error, device) {
    return callback(error, device);
  });
}

function errorResponse(error, res){
  if(error.code){
    res.statusCode = error.code;
    res.json(error);
  }else{
    res.statusCode = 400;
    res.json(400, error);
  }
}

function streamMessages(req, res, topic){
  var rs = createReadStream();
  var subHandler = function(topic, msg){
    rs.pushMsg(JSON.stringify(msg));
  };

  // subEvents.on(topic, subHandler);
  rs.pipe(res);

  //functionas a heartbeat.
  //If client stops responding, we can assume disconnected and cleanup
  var interval = setInterval(function() {
    res.write('');
  }, 10000);

  res.once('finish', function(err) {
    //监听到'finish'事件时关闭监听
    clearInterval(interval);
    // subEvents.removeListener(topic, subHandler);
  });

}

function subscribeBroadcast(req, res, type, skynet){
  authorizeRequest(req, res, function(fromDevice){
    skynet.sendActivity(getActivity(type, req, fromDevice));
    var uuid = req.params.uuid;
    logEvent(204, {fromUuid: fromDevice, uuid: uuid});
    //no token provided, attempt to only listen for public broadcasts FROM this uuid
    whoAmI(uuid, false, function(results) {
      if(results.error){
        return errorResponse(results.error, res);
      }

      securityImpl.canReceive(fromDevice, results, function(error, permission){
        if(permission) {
          return streamMessages(req, res, uuid + '_bc');
        }

        errorResponse({error: "unauthorized access"}, res);
      });

    });
  });
}

function s_responseMsg(res, error, data){

  var message = {};
  if (error) {
    res.statusCode = error.code || 400;
    delete error.code;
    message.t = 'err';
    message.p = error;
    message.s = false;
    return res.json(message);
  }

  message.s = true;
  if(data){
    message.p = data;
  }

  return res.json(message);

}

/**
 * 具体实现coap中的GET,POST,PUT,DELETE请求.
 */
function setupCoapRoutes(coapRouter, skynet){

  //TODO No reply in 247s at retry_send

  var subForwarder = new SubForwarder();

  //请求得到系统的状态
  coapRouter.get('/status', function (req, res) {
    skynet.sendActivity(getActivity('status', req));
    debug('status', req);
    getSystemStatus(function(){

        s_responseMsg(res, null, null);

    });
  });

  /**
   * 注册设备,将设备注册至mongodb中.
   */
  coapRouter.post('/register', function (req, res) {
    s_register(req.params, function (error, data) {

      return s_responseMsg(res, error, data);

    });
  });

  // coap get coap://localhost/whoami
  coapRouter.get('/whoAmI', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){
      return s_responseMsg(res, error, fromDevice);
    });
  });

  //终端升级设备配置,更新到mongodb中
  coapRouter.put('/update', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      updateFromClient(fromDevice, req.params, function(error, result){
        return s_responseMsg(res, error, result);
      });

    });
  });

  coapRouter.put('/updateList/:listName', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      req.params.api = 'push';

      s_updateList(fromDevice, req.params, function(error, result){
        return s_responseMsg(res, error, result);
      });

    });
  });

  coapRouter.delete('/updateList/:listName', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      req.params.api = 'pull';

      s_updateList(fromDevice, req.params, function(error, result){
        return s_responseMsg(res, error, result);
      });

    });
  });

  coapRouter.get('/device', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      s_getOneDevice(fromDevice, req.params, function(error, data){
        return s_responseMsg(res, error, data);
      });

    });
  });

  coapRouter.get('/devices', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      s_getDevices(fromDevice, req.params, function(error, data){
        return s_responseMsg(res, error, data);
      });

    });
  });

  coapRouter.post('/sesToken', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      getToken(fromDevice, req.params, function(error, result){
        return s_responseMsg(res, error, result);
      });

    });
  });

  coapRouter.delete('/device', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      unregister(fromDevice, req.params.uuid, null, function(error, result){
        return s_responseMsg(res, error, result);
      });

    });
  });

  //订阅uuid的received,config,data消息
  coapRouter.get('/subscribe', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      subForwarder.subscribe(fromDevice, res, req.params.uuid);

    });
  });

  //获取路径中uuid的broadcast,config,data类型的消息
  coapRouter.get('/subscribe/broadcast', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      subForwarder.subBroadcast(fromDevice, res, req.params.uuids);

    });
  });

  // coap post coap://localhost/messages -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
  //post('/smessages')发送的信息在namespace:sent:uuid和namespace:received:uuid通道中
  coapRouter.post('/message', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      //调用sendMessage文件中最后return的function
      skynet.sendMessage(fromDevice, req.params, null, function(error){
        //TODO 回调加第二个参数会出现null数组
        return s_responseMsg(res, error);

      });

    });
  });

  coapRouter.post('/broadcast', function (req, res) {
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      //调用sendMessage文件中最后return的function
      skynet.broadcast(fromDevice, req.params, null, function(error){

        return s_responseMsg(res, error);

      });

    });
  });

  //推送数据
  coapRouter.post('/data', function(req, res){
    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error, null);
      }

      saveData(fromDevice, req.params, function(error){

        return s_responseMsg(res, error);

      });

    });
  });

  coapRouter.post('/key', function(req, res){

    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error);
      }
      
      saveKey(fromDevice, req.params, function(error){
        return s_responseMsg(res, error);
      });

    });

  });

  coapRouter.get('/key', function(req, res){

    authorizeRequest(req, function(error, fromDevice){

      if(error){
        return s_responseMsg(res, error);
      }

      s_getKey(fromDevice, req.params, function(error, key){
        return s_responseMsg(res, error, key);
      });
      
    });

  });
  

  //请求重置路径中uuid设备token
  coapRouter.post('/token', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('resetToken', req, fromDevice));
      resetToken(fromDevice, fromDevice.uuid,skynet.emitToClient, function(err,token){
        if(err){
          s_responseMsg(res,null,err,null);
        } else {
          s_responseMsg(res,201,null,{uuid: fromDevice.uuid, token: token});
        }
      });
    });
  });



  coapRouter.post('/gatewayConfig', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('gatewayConfig', req, fromDevice));
      var body;
      try {
        body = JSON.parse(req.body);
      } catch(err) {
        logError(err, 'error parsing', req.body);
        body = {};
      }

      skynet.gatewayConfig(body, function(result){
        if(result && result.error){
          errorResponse(result.error, res);
        }else{
          res.json(result);
        }
      });

      logEvent(300, body);
    });
  });

}

module.exports = setupCoapRoutes;