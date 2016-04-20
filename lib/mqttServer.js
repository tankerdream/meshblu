'use strict';
var _ = require('lodash');
var mosca = require('mosca');
var whoAmI = require('./whoAmI');
var logData = require('./logData');
var resetToken = require('./resetToken');
var getPublicKey = require('./s_getPublicKey');
var securityImpl = require('./getSecurityImpl');
var proxyListener = require('./proxyListener');
var updateSocketId = require('./updateSocketId');
var MessageIOClient = require('./messageIOClient');
var wrapMqttMessage = require('./wrapMqttMessage');
var updateFromClient = require('./updateFromClient');
var MessageSender = require('./sendMessage');
var MeshbluEventEmitter = require('./MeshbluEventEmitter');
var saveDataIfAuthorized = require('./saveDataIfAuthorized');
var getToken = require('./s_generateAndStoreToken');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var debug = require('debug')('hyga:mqtt');

var authDevice = require('./authDevice');

var hyGaError = require('./models/hyGaError');
var s_updateSocketId = require('./s_updateSocketId');

//验证设备请求的合法性
function s_authorizeRequest(uuid, token, callback){

  var uuid = uuid;
  var token = token;

  if(!uuid || !token){
    return callback(hyGaError(401, 'Unauthorized'));
  }
  uuid = uuid.toString();
  token = token.toString();

  authDevice(uuid, token, function (error, device) {
    if(error){
      return callback(error);
    }

    if(!device){
      return callback(hyGaError(401,'Unauthorized'));
    }

    return callback(null,device);
  });

}

var mqttServer = function(config, parentConnection){
  var server;

  var dataLogger = {
      level: 'warn'
  };

  var settings = {
    port: config.mqtt.port || 1883,
    logger: dataLogger,
    stats: config.mqtt.stats || false
  };

  config.mqtt = config.mqtt || {};

  if(config.redis && config.redis.host){
    var ascoltatore = {
      type: 'redis',
      redis: require('redis'),
      port: config.redis.port || 6379,
      return_buffers: true, // to handle binary payloads
      host: config.redis.host || "localhost"
    };
    settings.backend = ascoltatore;
    settings.persistence= {
      factory: mosca.persistence.Redis,
      host: ascoltatore.host,
      port: ascoltatore.port
    };

  }else if(config.mqtt.databaseUrl){
    settings.backend = {
      type: 'mongo',
      url: config.mqtt.databaseUrl,
      pubsubCollection: 'mqtt',
      mongo: {}
    };
  }else{
    settings.backend = {};
  }

  var skynetTopics = [
    'message',
    'update',
    'broadcast',
    'subBroadcast',
    'unsubBroadcast',
    'config',
    'whoami',
    'getPublicKey',
    'getToken',
    'messageAck',
    'tb',
  ];

  function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
  }

  var socketEmitter = createMessageIOEmitter();

  function mqttEmitter(uuid, wrappedData, options){
    options = options || {};
    var message = {
      topic: uuid,
      payload: wrappedData, // or a Buffer
      qos: options.qos || 0, // 0, 1, or 2
      retain: false // or true
    };
    debug('publish (mqttEmitter)', message);
    server.publish(message, _.noop);
  }

  // Use this for sending messages to client
  function emitToClientDirectly(uuid, message, options){
    options = _.defaults(options, {qos: 0});
    mqttEmitter(uuid, wrapMqttMessage(message), options);
  }

  function hyga_emitClient(uuid, type, error, message, request){
    debug('hyga_emitClient eror', error);
    debug('hyga_emitClient message', message);
    debug('hyga_emitClient request', request);

    var resp = {};
    if(request && request.callbackId){
      resp._callbackId = request.callbackId;
    }

    var qos = 1;
    if(error){
      resp.type = 'error';
      resp.success = false;
      resp.payload = error;
      return emitToClientDirectly(uuid, resp, {qos: qos});
    }
    qos = message.qos || qos;
    resp.type = type;
    resp.success = true;
    resp.payload = message;
    return emitToClientDirectly(uuid, resp, {qos: qos});
  }

  var messageSender= new MessageSender(socketEmitter, mqttEmitter, parentConnection);
  var sendMessage = messageSender.hyga_sendMessage;
  var broadcast = messageSender.hyga_broadcast;

  var meshbluEventEmitter = new MeshbluEventEmitter(config.uuid, config.forwardEventUuids, sendMessage);
  if(parentConnection){
    parentConnection.on('message', function(data, fn){
      if(data){
        var devices = data.devices;
        if (!_.isArray(devices)) {
          devices = [devices];
        }
        _.each(devices, function(device) {
          if(device !== config.parentConnection.uuid){
            sendMessage({uuid: data.fromUuid}, data, fn);
          }
        });
      }
    });
  }

  // Accepts the connection if the username and password are valid
  function authenticate(client, uuid, token, callback) {

    s_authorizeRequest(uuid, token,function(error,device) {

      if(error){
        callback(error,false);
      }
      //TODO  auto_set_online
      debug('MQTT auth', uuid);

      var data = {
        uuid: uuid,
        ipAddress: client.connection.stream.remoteAddress,
        protocol: 'mqtt',
        online: true
      };

      s_updateSocketId(data, function(auth){
        if(!auth.device){
          return callback(hyGaError(401,'Unauthorized'),false);
        }
        client.skynetDevice = auth.device;

        debug('connecting for client', client.id);
        client.messageIOClient = new MessageIOClient();

        client.messageIOClient.on('message', function(message){
          debug(client.id, 'relay mqtt message', message);
          hyga_emitClient(client.skynetDevice.uuid,'message',message);
        });

        client.messageIOClient.on('data', function(message){
          debug(client.id, 'relay mqtt data', message);
          hyga_emitClient(client.skynetDevice.uuid,'data',message);
        });

        client.messageIOClient.on('config', function(message){
          debug(client.id, 'relay mqtt config', message);
          //TODO 设备配置更改后会通过钩子发送到这里信息
          //hyga_emitClient(client.skynetDevice.uuid,'config',message);
          //emitToClientDirectly(client.skynetDevice.uuid, {type: 'config', payload: message}, {qos: message.qos || 0});
        });

        client.messageIOClient.on('broadcast', function(message){
          debug(client.id, 'relay mqtt broadcast', message);
          hyga_emitClient(client.skynetDevice.uuid,'broadcast',message);
        });

        debug(client.id, 'subscribing to received', client.skynetDevice.uuid);
        client.messageIOClient.subscribe(client.skynetDevice.uuid);
        callback(null, true);
      });

    });

  }

  // In this case the client authorized as alice can publish to /users/alice taking
  // the username from the topic and verifing it is the same of the authorized user
  function authorizePublish(client, topic, payload, callback) {

    if(!client.skynetDevice){
      return callback(hyGaError(401,'Unauthorized'));
    }
    if(client.skynetDevice.uuid === 'skynet'){
      callback(null, true);
    }else if(_.contains(skynetTopics, topic)){
      var payload = payload.toString();
      try{
        var payloadObj = JSON.parse(payload);
        payloadObj.fromUuid = client.skynetDevice.uuid;
        callback(null, new Buffer(JSON.stringify(payloadObj)));
      }catch(exp){
        callback(hyGaError(400,'Invalid payload'));
      }
    }else{
      callback(hyGaError(400,'Invalid topic'));
    }

  }

  // In this case the client authorized as alice can subscribe to /users/alice taking
  // the username from the topic and verifing it is the same of the authorized user
  function authorizeSubscribe(client, topic, callback) {
    if(!client.skynetDevice){
      return callback(hyGaError(401,'Unauthorized'));
    }
    if(endsWith(topic, '_bc') || endsWith(topic, '_tb')){
      return callback(null, true);
    }
    if(client.skynetDevice.uuid === 'skynet' || client.skynetDevice.uuid === topic){
      return callback(null, true);
    }
  }

  // fired when the mqtt server is ready
  function setup() {
    if (config.useProxyProtocol) {
      _.each(server.servers, function(server){
        proxyListener.resetListeners(server);
      })
    }

    server.authenticate = authenticate;
    server.authorizePublish = authorizePublish;
    server.authorizeSubscribe = authorizeSubscribe;
    console.log('MQTT listening at mqtt://0.0.0.0:' + settings.port);
  }

  // // fired when a message is published
  server = new mosca.Server(settings);

  server.on('ready', setup);

  _.each(server.servers, function(singleServer){
    singleServer.on('error', function(error){
      debug('error event for mqtt server', error);
    });
  })

  server.on('clientConnected', function(client) {
    debug('client connected:', client.id);
  });

  server.on('clientDisconnected', function(client) {

    debug('client disconnected:', client.id);

    if (client.messageIOClient) {
      client.messageIOClient.close();
    }

    var data = {
      uuid: client.skynetDevice.uuid,
      online: false
    }
    s_updateSocketId(data, function(){});

  });

  function parsePacket(packet){
    var topic, payload, parsedPayload;
    topic = packet.topic;
    payload = packet.payload || '';
    if(payload instanceof Buffer){
      payload = payload.toString();
    }

    try{
      parsedPayload = JSON.parse(payload);
    }catch(parseError){}

    if(parsedPayload && _.isPlainObject(parsedPayload)){
      payload = parsedPayload;
    }

    return {
      payload: payload,
      topic: topic
    }
  }

  server.on('subscribed', function(topics, client){
    debug('client subscribed', topics, client.id);
  });

  server.on('published', function(packet, client) {
    var msg, ack, payload, packetObj, sanitizedRequest, topic, request;
    packetObj = parsePacket(packet);
    payload = packetObj.payload;
    topic = packetObj.topic;
    if(!topic || !_.contains(skynetTopics, topic)){
      return;
    }

    debug('on published', 'topic:', topic, 'payload:', payload);
    msg = _.cloneDeep(payload);
    request = _.cloneDeep(payload);
    sanitizedRequest = _.omit(_.cloneDeep(payload), 'fromUuid', 'callbackId');

    if('message' === topic){
      debug('sendMessage', msg);
      sendMessage(client.skynetDevice, msg.payload, null, function(error, resp){
        return hyga_emitClient(client.skynetDevice.uuid, 'resp', error, resp, request);
      });
    }
    else if('broadcast' === topic){
      debug('broadcast', msg.payload);
      broadcast(client.skynetDevice, msg);
    }
    else if('subBroadcast' === topic){
      debug('subBroadcast', msg);
      client.messageIOClient.subBroadcast(client.skynetDevice, msg.devices);
    }
    else if('unsubBroadcast' === topic){
      debug('unsubBroadcast', msg);
      client.messageIOClient.unsubBroadcast(client.skynetDevice, msg.devices);
    }
    else if('update' === topic){
      updateFromClient(client.skynetDevice, msg.payload, function(error, data){
        hyga_emitClient(client.skynetDevice.uuid, 'resp', error, data, request);
      });
    }
    else if('getToken' === topic){
      getToken(client.skynetDevice, msg.payload, function(error, result){
        hyga_emitClient(client.skynetDevice.uuid, 'resp', error, result, request);
      });
    }
    else if('getPublicKey' === topic) {
      getPublicKey(client.skynetDevice, msg.payload.uuid, function(error, publicKey){
        hyga_emitClient(client.skynetDevice.uuid, 'resp', error, {publicKey: publicKey}, request);
      })
    }
    else if('whoami' === topic){
      whoAmI(client.skynetDevice.uuid, true, function(error, resp){
        hyga_emitClient(client.skynetDevice.uuid, 'resp', error, resp, request);
      });
    }
  });
};

module.exports = mqttServer;
