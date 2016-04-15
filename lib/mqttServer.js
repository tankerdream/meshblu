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
var generateAndStoreToken = require('./generateAndStoreToken');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var debug = require('debug')('meshblu:mqtt');

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
    'config',
    'whoami',
    'resetToken',
    'getPublicKey',
    'generateAndStoreToken',
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

  // This is just for configActivity
  function emitToClient(topic, device, msg){
    emitToClientDirectly(device.uuid, {topic: topic, payload: msg});
  }

  function hyga_emitClient(uuid,type,message){

    var qos = message.qos || 0;
    delete message.qos;
    emitToClientDirectly(uuid, {type: type, payload: message}, {qos: qos});

  }

  var  messageSender= new MessageSender(socketEmitter, mqttEmitter, parentConnection);
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
          hyga_emitClient(client.skynetDevice.uuid,'config',message);
          //emitToClientDirectly(client.skynetDevice.uuid, {type: 'config', payload: message}, {qos: message.qos || 0});
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
      sendMessage(client.skynetDevice, msg);
      //meshbluEventEmitter.log('message', null, {request: sanitizedRequest, fromUuid: client.skynetDevice.uuid});
    }
    else if('broadcast' === topic){
      debug('broadcast', msg);
      broadcast(client.skynetDevice, msg);
    }
    else if('subBroadcast' === topic){
      debug('subBroadcast', msg);
      broadcast(client.skynetDevice, msg);
    }
    else if('update' === topic){
      updateFromClient(client.skynetDevice, msg, function(data){
        debug('updateFromClient', arguments);
        var logRequest = {params: {$set: sanitizedRequest}, query: {uuid: sanitizedRequest.uuid}};
        var errorMessage = data.error && data.error.message;
        meshbluEventEmitter.log('update', data.error, {request: logRequest, fromUuid: client.skynetDevice.uuid, error: errorMessage});

        var message = {topic: 'update', payload: {}, _request: request};
        if(errorMessage){
          message.topic = 'error';
          message.payload.message = errorMessage;
        }
        emitToClientDirectly(client.skynetDevice.uuid, message);
      });
    }
    else if('resetToken' === topic){
      resetToken(client.skynetDevice, msg.uuid, emitToClient, function(error, token){
        var errorMessage = error || undefined;

        meshbluEventEmitter.log('resettoken', error, {request: {uuid: msg.uuid}, fromUuid: client.skynetDevice.uuid, error: errorMessage});
        if(error != null){
          return emitToClientDirectly(client.skynetDevice.uuid, {topic: 'error', payload: {message: error}, _request: request});
        }
        var message = {topic: 'token', payload: {uuid: msg.uuid, token: token}, _request: request};
        emitToClientDirectly(client.skynetDevice.uuid, message);
      });
    }
    else if('generateAndStoreToken' === topic){
      generateAndStoreToken(client.skynetDevice, msg, function(error, result){
        var errorMessage = error && error.message || undefined;
        meshbluEventEmitter.log('generatetoken', error, {request: {uuid: msg.uuid}, fromUuid: client.skynetDevice.uuid, error: errorMessage});
        if(error != null){
          return emitToClientDirectly(client.skynetDevice.uuid, {topic: 'error', payload: error, _request: request});
        }
        var message = {topic: 'generateAndStoreToken', payload: {uuid: msg.uuid, token: result.token, tag: msg.tag}, _request: request};
        emitToClientDirectly(client.skynetDevice.uuid, message);
      });
    }
    else if('getPublicKey' === topic) {
      getPublicKey(msg.uuid, function(error, publicKey){
        var errorMessage = error && error.message || undefined;
        meshbluEventEmitter.log('getpublickey', error, {request: sanitizedRequest, error: errorMessage});
        if(error != null){
          return emitToClientDirectly(client.skynetDevice.uuid, {topic: 'error', payload: error, _request: request});
        }
        var message = {topic: 'publicKey', payload: {publicKey: publicKey}, _request: request};
        emitToClientDirectly(client.skynetDevice.uuid, message);
      })
    }
    else if('whoami' === topic){
      whoAmI(client.skynetDevice.uuid, true, function(resp){
        meshbluEventEmitter.log('whoami', null, {request: sanitizedRequest, fromUuid: client.skynetDevice.uuid});
        //emitToClientDirectly(client.skynetDevice.uuid, {topic: 'whoami', payload: resp, _request: request});
        hyga_emitClient(client.skynetDevice.uuid,'whoami',resp);
      });
    }
  });
};

module.exports = mqttServer;
