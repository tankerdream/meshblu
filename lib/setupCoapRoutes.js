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
var s_saveDataIfAuthorized = require('./s_saveDataIfAuthorized');

var s_register = require('./s_register');
var s_unregister = require('./s_unregister');
var s_getPublicKey = require('./s_getPublicKey');

function getActivity(topic, req, device, toDevice){
  var ip = req.rsinfo.address;
  return createActivity(topic, ip, device, toDevice);
}

//psuedo middleware
//验证请求的token是否正确,正确则返回设备
function authorizeRequest(req, res, next){
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
    if(error){
      return s_responseMsg(res,401,error,null);
    }
    if(!device){
      return s_responseMsg(res,null,{code:401,message:'unauthorized'},null);
    }

    return next(device);
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

function s_responseMsg(res,statusCode,error,data){

  if(error){
    res.statusCode = error.code || 400;
    delete(error.code);
    return  res.json(error);
  }

  res.statusCode = statusCode;

  return res.json(data);

}

/**
 * 具体实现coap中的GET,POST,PUT,DELETE请求.
 */
function setupCoapRoutes(coapRouter, skynet){

  //TODO No reply in 247s at retry_send

  /**
   * 注册设备,将设备注册至mongodb中.
   */
  coapRouter.post('/register', function (req, res) {

    req.params.ipAddress = req.params.ipAddress || req.rsinfo.address;

    var s_channel = req.params.channel

    s_register(s_channel,req.params, function (error, data) {

      return s_responseMsg(res,201,error,data);

    });

  });

  //推送数据
  coapRouter.post('/data', function(req, res){
    authorizeRequest(req, res, function(fromDevice){

      skynet.sendActivity(getActivity('data', req, fromDevice));

      s_saveDataIfAuthorized(skynet.sendMessage, fromDevice, req.params, function(error){

        var statusCode;
        var data;
        if(error) {
          statusCode = 500;
        }else{
          statusCode = 201;
        }

        return s_responseMsg(res,statusCode,error,data);

      });

    });
  });

  // coap post coap://localhost/messages -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
  //post('/smessages')发送的信息在namespace:sent:uuid和namespace:received:uuid通道中
  coapRouter.post('/message', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('messages', req, fromDevice));
      var body;
      try {
        body = JSON.parse(req.params);
      } catch(err) {
        body = req.params;
      }
      if (!body.devices){
        try {
          body = JSON.parse(req.params);
        } catch(err) {
          body = req.params;
        }
      }
      var devices = body.devices;
      var message = {};
      message.payload = body.payload;
      message.devices = body.devices;
      message.subdevice = body.subdevice;
      message.topic = body.topic;

      //调用sendMessage文件中最后return的function
      skynet.sendMessage(fromDevice, message,null,function(error){

        var statusCode;
        var data;
        if(error) {
          statusCode = 500;
        }else{
          statusCode = 201;
          data = {devices:devices, payload: body.payload}
          logEvent(300, data);
        }

        return s_responseMsg(res,statusCode,error,data);

      });

    });
  });

  //订阅uuid的broadcast,received,sent,config,data消息
  coapRouter.get('/subscribe', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token);
    });
  });

  //获取路径中uuid的received,config,data类型的消息
  coapRouter.get('/subscribe/received', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, ['received'], false);

    });
  });


  //获取路径中uuid的sent,config,data类型的消息
  coapRouter.get('/subscribe/sent', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, ['sent'], false);
    });
  });

  //获取路径中uuid的broadcast,config,data类型的消息
  coapRouter.get('/subscribe/broadcast', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, ['broadcast'], false);
    });
  });

  //终端升级设备配置,更新到mongodb中
  coapRouter.put('/device', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));

      req.params.ipAddress = req.params.ipAddress || req.rsinfo.address;
      updateFromClient(fromDevice, req.params, function(result){

        if(result.error){
          return s_responseMsg(res,500,result,null);
        }else{
          //将配置结果发送给设备
          return s_responseMsg(res,401,null,result);
        }

      });
    });
  });

  //请求得到ip地址
  coapRouter.get('/ipaddress', function (req, res) {
    skynet.sendActivity(getActivity('ipaddress', req));
    return s_responseMsg(res,200,null,{ipAddress: req.rsinfo.address});
  });

  //请求得到系统的状态
  coapRouter.get('/status', function (req, res) {
    skynet.sendActivity(getActivity('status', req));

    getSystemStatus(function (data) {
      if(data.error) {
        s_responseMsg(res,null,data.error,null);
      } else {
        s_responseMsg(res,200,null,data);
      }

    });
  });

  //获取uuid所对应的设备信息
  coapRouter.get('/device', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){

      req.params.uuid = req.params.uuid || fromDevice.uuid

      skynet.sendActivity(getActivity('devices', req, fromDevice));
      getDevices(fromDevice, {uuid: req.params.uuid}, false, function(error,data){
        if(error){
          s_responseMsg(res,null,error,null);
        }else{
          s_responseMsg(res,201,null,data);
        }
      });
    });
  });

  //查询满足查询条件的设备,可以在payload中附加查询条件
  coapRouter.get('/devices', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));

      getDevices(fromDevice, req.query, false, function(error,data){

        if(error){
          s_responseMsg(res,null,error,null);
        }else{
          s_responseMsg(res,201,null,data);
        }

      });

    });
  });

  //删除设备
  coapRouter.delete('/device', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){

      req.params.uuid = req.params.uuid || fromDevice.uuid

      skynet.sendActivity(getActivity('unregister', req, fromDevice));
      s_unregister(fromDevice, req.params.uuid, req.params.token, skynet.emitToClient, function(err, data){
        if(err){
          s_responseMsg(res,null,err,null);
        } else {
          s_responseMsg(res,201,null,data);
        }
      });
    });

  });

  //删除其它设备
  coapRouter.delete('/devices', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('unregister', req, fromDevice));
      s_unregister(fromDevice, req.params.uuid, req.params.token, skynet.emitToClient, function(err, data){
        if(err){
          s_responseMsg(res,null,err,null);
        } else {
          s_responseMsg(res,201,null,data);
        }
      });
    });
  });

  //获取设备的公共键值,可访问的属性
  coapRouter.get('/publickey', function(req, res){
    authorizeRequest(req, res, function(fromDevice){

      s_getPublicKey(fromDevice, req.params.uuid, function(err, publicKey){
        if(err){
          s_responseMsg(res,null,err,null);
        } else {
          s_responseMsg(res,201,null,publicKey);
        }
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





  // coap get coap://localhost/status
  //请求得到系统的状态
  coapRouter.get('/sstatus', function (req, res) {
    skynet.sendActivity(getActivity('status', req));

    getSystemStatus(function (data) {
      if(data.error) {
        res.statusCode = data.error.code;
        res.json(data.error);
      } else {
        res.statusCode = 200;
        res.json(data);
      }
    });
  });

  // coap get coap://localhost/ipaddress
  //请求得到ip地址
  coapRouter.get('/sipaddress', function (req, res) {
    skynet.sendActivity(getActivity('ipaddress', req));
    res.json({ipAddress: req.rsinfo.address});
  });

  //查询满足查询条件的设备,可以在payload中附加查询条件
  coapRouter.get('/sdevices', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));

      getDevices(fromDevice, req.query, false, function(error, data){
        if(data.error){
          errorResponse(data.error, res);
        }else{
          res.json(data);
        }
      });

    });
  });

  //注册设备,将设备注册至mongodb中
  coapRouter.post('/devices', function (req, res) {
    skynet.sendActivity(getActivity('devices', req));

    req.params.ipAddress = req.params.ipAddress || req.rsinfo.address;
    register(req.params, function (error, data) {
      if(error) {
        res.statusCode = 500;
        return res.json(error.msg);
      }

      res.statusCode = 201;

      res.json(data);
    });
  });

  // coap get coap://localhost/devices/a1634681-cb10-11e3-8fa5-2726ddcf5e29
  //获取uuid所对应的设备信息
  coapRouter.get('/sdevices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));

      getDevices(fromDevice, {uuid: req.params.uuid}, false, function(error, data){
          if(data.error){
            errorResponse(data.error, res);
          }else{
            res.json(data);
          }
        });
    });
  });

  //终端升级设备配置,更新到mongodb中
  coapRouter.put('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));

      req.params.ipAddress = req.params.ipAddress || req.rsinfo.address;
      updateFromClient(fromDevice, req.params, function(result){
        if(result.error){
          errorResponse(result.error, res);
        }else{
          //将配置结果发送给设备
          res.json(result);
        }
      });
    });
  });

  //删除设备
  coapRouter.delete('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('unregister', req, fromDevice));
      unregister(fromDevice, req.params.uuid, req.params.token, skynet.emitToClient, function(err, data){
        if(err){
          errorResponse(err, res);
        } else {

          res.json(data);
        }
      });
    });

  });

  //请求重置路径中uuid设备token
  coapRouter.post('/devices/:uuid/token', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('resetToken', req, fromDevice));
      resetToken(req.params.uuid, fromDevice, skynet.emitToClient, function(err,token){
        if(err){
          errorResponse(err, res);
        } else {
          res.json({uuid: req.params.uuid, token: token});
        }
      });
    });
  });

  //为设备加入meshblu.token.#hashedToken
  coapRouter.post('/devices/:uuid/tokens', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('generateAndStoreToken', req, fromDevice));

      generateAndStoreToken(fromDevice, req.params.uuid, function(error, result){
        if(error){
          return errorResponse(error, res);
        }

        var uuid = fromDevice.uuid;

        res.json({uuid: uuid, token: result.token});
      });
    });
  });

  //获取本设备的状态
  coapRouter.get('/mydevices', function (req, res) {
    var query = req.query || {};
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('mydevices', req, fromDevice));
      query.owner = fromDevice.uuid;
      authDevices(fromDevice, query, true, function(data){
        if(data.error){
          errorResponse(data.error, res);
        } else {
          res.json(data);
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

  // coap get coap://localhost/events/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29"
  //从mongodb中获取与uuid相关的事件的数据
  coapRouter.get('/events/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('events', req, fromDevice));
      logEvent(201, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      getEvents(fromDevice.uuid, function(data){
        if(data.error){
          errorResponse(data.error, res);
        } else {
          res.json(data);
        }
      });
    });
  });


  // coap post coap://localhost/data/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29&temperature=43"
  //推送数据
  coapRouter.post('/sdata/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('data', req, fromDevice));
      delete req.params.token;

      //req.params.ipAddress = getIP(req);
      saveDataIfAuthorized(skynet.sendMessage, fromDevice, req.params.uuid, req.params, function(error, saved){
        res.json(saved);
      });
    });
  });

  // coap get coap://localhost/data/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29&limit=1"
  //获取uuid的事件数据或者订阅uuid的广播信息
  coapRouter.get('/data/:uuid', function(req, res){
    if(req.query.stream){
      subscribeBroadcast(req, res, 'data', skynet);
    }
    else{
      authorizeRequest(req, res, function(fromDevice){
        skynet.sendActivity(getActivity('data',req, fromDevice));
        getData(req, function(data){
          if(data.error){
            errorResponse(data.error, res);
          } else {
            res.json(data);
          }
        });
      });
    }
  });

  // coap post coap://localhost/messages -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
  //
  coapRouter.post('/smessages', function (req, res, next) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('messages', req, fromDevice));
      var body;
      try {
        body = JSON.parse(req.params);
      } catch(err) {
        body = req.params;
      }
      if (!body.devices){
        try {
          body = JSON.parse(req.params);
        } catch(err) {
          body = req.params;
        }
      }
      var devices = body.devices;
      var message = {};
      message.payload = body.payload;
      message.devices = body.devices;
      message.subdevice = body.subdevice;
      message.topic = body.topic;

      //调用sendMessage文件中最后return的function
      skynet.sendMessage(fromDevice, message);
      res.json({devices:devices, subdevice: body.subdevice, payload: body.payload});

      logEvent(300, message);
    });
  });

  //订阅uuid的消息
  coapRouter.get('/ssubscribe', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token);
    });
  });

  //订阅特定类型,主题的的消息
  coapRouter.get('/subscribe/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});

      var requestedSubscriptionTypes = req.merged_params.types || ['broadcast', 'received', 'sent'];
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, requestedSubscriptionTypes, false, req.merged_params.topics );

    });
  });

  //获取broadcast类型的消息
  coapRouter.get('/subscribe/:uuid/broadcast', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, ['broadcast'], false, req.merged_params.topics);
    });
  });

  //获取received类型的消息
  coapRouter.get('/subscribe/:uuid/received', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, ['received'], false, req.merged_params.topics);

    });
  });

  //获取sent类型的消息
  coapRouter.get('/subscribe/:uuid/sent', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      subscribeAndForward(fromDevice, res, req.params.uuid, req.params.token, ['sent'], false, req.merged_params.topics);
    });
  });

  // coap get coap://localhost/whoami
  coapRouter.get('/whoami', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('whoami', req, fromDevice));
      whoAmI(fromDevice.uuid, false, function(results) {
        if(results.error){
          errorResponse(results.error, res);
        }else{
          res.json(results);
        }
      });
    });
  });
}

module.exports = setupCoapRoutes;