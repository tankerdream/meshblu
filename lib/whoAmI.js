var getDevice = require('./getDevice');

//根据uuid返回设备
module.exports = function(uuid, callback) {
  getDevice(uuid, function(error, device) {
    if (!device) {
      device = {};
    }
    callback(error, device);
  });
};
