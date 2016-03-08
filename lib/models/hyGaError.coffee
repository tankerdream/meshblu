#错误信息
hyGaError = (code,msg,data)->
  res =
    code:code
    error:
      data
  res.msg = msg
  return res

module.exports = hyGaError
