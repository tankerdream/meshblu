var qs    = require('qs'),
    parse = require('url').parse,
    _     = require('lodash');

/**
 * 建立Coap的路由
 * @constructor coapRouter
 * @class
 * @tutorial socket-tutorial
 */
var coapRouter = {
  routes : [],

  /**
   * 对输入的格式进行规则编译
   * @constructor
   * @param {string} pattern - 编译规则
   */
  compilePattern : function (pattern) {
    if(pattern instanceof RegExp) return pattern;

    var fragments = pattern.split(/\//);
    return fragments.reduce(
      function (route, fragment, index, fragments) {
        if(fragment.match(/^\:/)) {
          route.tokens.push(fragment.replace(/^\:/, ''));
          route.fragments.push('([a-zA-Z0-9-_~\\.%@]+)');
        } else {
          route.fragments.push(fragment);
        }

        if(index === (fragments.length - 1)) route.regexp = route.compileRegExp();
        return route;
      },
      {
        fragments     : [],
        tokens        : [],
        compileRegExp : function () { return new RegExp(this.fragments.join("\\/") + "$"); },
        regexp        : ''
      }
    );
  },
  add : function (method, pattern, callback) {
    //为coapRouter添加不同的route
    var route = this.compilePattern(pattern);
    route.method   = method;
    //route路径的验证规则
    route.pattern  = route.regexp;
    route.callback = callback;

    this.routes.push(route);
    return this;
  },
  "get"    : function (pattern, callback) { return this.add('get', pattern, callback);    },
  "post"   : function (pattern, callback) { return this.add('post', pattern, callback);   },
  "put"    : function (pattern, callback) { return this.add('put', pattern, callback);    },
  "delete" : function (pattern, callback) { return this.add('delete', pattern, callback); },
  find : function (method, url) {
    //找到指定method、url对应的route
    var routes = this.routes.filter(function (route) {
      return (route.method === method && url.match(route.pattern));
    });
    return routes[0];
  },
  parseValues : function (url, route) {
    //解析请求路径中的参数，返回的键值数组对，键为token，值为参数
    var tokenLength = route.tokens.length + 1;
    var matches     = url.match(route.pattern);
    var values      = matches.slice(1, tokenLength);
    return route.tokens.reduce(function (finalValues, token, index, tokens) {
      finalValues[token] = values[index];
      return finalValues;
    }, {});
  },
  attachQuery : function (request) {
    //对请求进行格式化，便于后续对请求的操作
    var query = request.options.filter(function (option) { return option.name === 'Uri-Query'; });
    if(query) {
      query = query.reduce(function (options, option, index, query) {
        return _.extend(options, qs.parse(option.value.toString()));
      }, {});
    }

    var params = request.payload;

    if(params && params.length > 0) {
      try {
        params = JSON.parse(params.toString());
      } catch (e) {
        if(e instanceof SyntaxError) {
          params = params.toString().replace(/^\/.*\?/g, '');
          params = qs.parse(params);
        }
      }
    } else { params = {}; }

    params = _.extend(params, query);
    query  = params;

    request.query  = query;
    request.params = params;

    return request;
  },
  attachJson : function (response) {
    //为响应res附加消息发送函数，响应通过json发送消息
    response.json = function (data) {
      response.setOption("Content-Format", "application/json");
      response.end(JSON.stringify(data));
    };
    return response;
  },
  process : function (request, response) {
    /** 处理CoAP服务器接收到的request请求 */
    coapRouter.attachQuery(request);
    coapRouter.attachJson(response);

    var method    = request.method ? request.method.toLowerCase() : 'get',
        url       = parse(request.url).pathname;

    var route     = coapRouter.find(method, url);

    if(route) {
      var callback  = route.callback,
          values    = coapRouter.parseValues(url, route);

      _.extend(request.params, values);

      callback.apply(callback, [request, response]);
    } else {
      response.statusCode = 404;
      response.json({error: {message: "We could not find that resource", code: 404}});
    }
  }
};

module.exports = coapRouter;
