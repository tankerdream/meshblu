var _ = require('lodash');
var config = require('./../config');

//将用到的设备缓存到redis中,加快查找设备的速度
if (config.redis && config.redis.host) {
  module.exports = require('./cacheDeviceRedis');
} else {
  module.exports = _.noop;
}

