jsBeautify = (require 'js-beautify').js_beautify
express = require 'express'
_ = require 'underscore'

module.exports = (options = {}) ->
  {port, ip} = options

  app_info =
    empty: true
    settings: {}
    global_middleware: []
    router_description: []
    api_description: []

  reflectApp = (app) ->
    global_middleware = _.filter app._router.stack, (layer) ->
      return layer.regexp.test '/'

    global_middleware = _.map global_middleware, (layer) ->
      return {
        name: layer.name
        source: jsBeautify layer.handle.toString()
      }

    _.extend app_info,
      empty: false
      settings: app.settings
      global_middleware: global_middleware

  createExplorerServer = ->
    explorer = express()

    explorer.get '/', (req, res) ->
      res.json app_info

    if ip != undefined
      explorer.listen (port ? 1839), ip
    else
      explorer.listen (port ? 1839)

  createExplorerServer()

  return (req, res, next) ->
    if app_info.empty
      reflectApp req.app

    next()
