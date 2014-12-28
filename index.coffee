jsBeautify = (require 'js-beautify').js_beautify
express = require 'express'
fs = require 'fs'
_ = require 'underscore'

fixPath = (path) ->
  if path[... 2] == '//'
    return path[1 ...]

  if path[-1 ...] == '/'
    return path[... -1]

  return path

formatPathRegex = (regex, base = '') ->
  format = ->
    regex.toString()
    .replace /^\/\^/, ''
    .replace /\/i?$/, ''
    .replace /\\/g, ''
    .replace '/?(?=/|$)', ''
    .replace /\/$/, ''

  if regex
    path = base + format regex

    unless path
      return '/'

    return fixPath path
  else
    return '/'

funcSource = (func) ->
  return jsBeautify func.toString()

module.exports = (options = {}) ->
  {port, ip} = options

  app_info =
    empty: true
    package: JSON.parse fs.readFileSync('./package.json').toString()
    settings: {}
    middleware: [
      name: 'serveStatic'
      source: ''
    ]
    router: [
      path: '/account/login'
      method: 'GET'
    ]

  reflectApp = (app) ->
    middlewares = []
    routers = []

    reflectRouter = (router, base = '') ->
      base = '' if base == '/'

      for layer in router.stack
        if layer.route
          for route_layer in layer.route.stack
            routers.push
              path: fixPath base + layer.route.path
              method: route_layer.method.toUpperCase()
              source: funcSource route_layer.handle
        else if layer.handle.stack
          base_path = base + formatPathRegex(layer.regexp)
          reflectRouter layer.handle, base_path
        else
          middlewares.push
            path: formatPathRegex layer.regexp, base
            name: layer.name
            source: funcSource layer.handle

    reflectRouter app._router

    _.extend app_info,
      empty: false
      settings: app.settings
      middleware: middlewares
      router: routers

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
