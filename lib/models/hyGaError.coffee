#错误信息
hyGaError = (code,msg,data)->
  res =
    code:code
    error:msg
  res.info = data
  return res

module.exports = hyGaError
