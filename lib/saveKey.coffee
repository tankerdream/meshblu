hyGaError = require './models/hyGaError';
updateFromClient = require './updateFromClient';

module.exports = (fromDevice, key, callback=_.noop) ->

  return callback hyGaError(400,'No key') unless key?

  updateFromClient fromDevice, {"key": key}, (error)=>
    return callback error