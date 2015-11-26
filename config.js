var _ = require('lodash');
var winston = require('winston');
var privateKey = 'hello';
var publicKey = 'hey';

module.exports = {
  mongo: {
    // databaseUrl: "192.168.1.105:6991/test"
    databaseUrl:"127.0.0.1:27017/test"
  },
  port: 80,
  uuid: "5d36c839-10df-408d-ba1c-5a6e9ef10966",
  token: 'hellolvjianyaoshinetankerdream',
  redis: {
    // host: "192.168.1.105",
    // port: 6379
    host: "127.0.0.1",
    port: 6379
  },
  coap: {
    port: 6661,
    // host: "192.168.1.105"
    host:"127.0.0.1"
  },
 messageBus: {
   port: 7777
 },
 preservedDeviceProperties: ['geo', 'ipAddress', 'lastOnline', 'onlineSince', 'owner', 'timestamp'],
 privateKey: privateKey,
 publicKey: publicKey
};
