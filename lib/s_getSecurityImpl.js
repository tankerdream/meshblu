var config = require('./../config');

//安全验证管理，用户可以在securityImpl中配置自定义安全验证
var securityModule;
if (config.securityImpl) {
  securityModule = require(config.securityImpl);
} else {
  SimpleAuth = require('../lib/s_simpleAuth');
  securityModule = new SimpleAuth
}

module.exports = securityModule;
