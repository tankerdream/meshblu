var _ = require('lodash');

module.exports = function(callback) {
  callback = callback || _.noop;
  _.defer(callback, {s: true});
}
