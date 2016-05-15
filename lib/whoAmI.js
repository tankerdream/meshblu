var config = require('./../config');
var getDevice = require('./getDevice');

//根据uuid返回设备
module.exports = function(uuid, owner, callback) {
  getDevice(uuid, function(error, device) {
    if (!device) {
      device = {};
    }
    callback(error, device);
  });
};
