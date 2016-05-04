var hyGaError = require('./models/hyGaError');

var httpParserError = function(logger) {

  return function(error, req, res, next) {

    if (error) {
      if (error instanceof SyntaxError) {
        res.status(400).json(hyGaError(400,'Invalid request body'));
        return;
      } else {

        if (logger) {
          logger.error(error);
        }

        res.status(500).json(hyGaError(500,'Server error'));
        return;

      }
    }

    next();
  };

};

module.exports = httpParserError;