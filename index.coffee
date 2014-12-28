jsBeautify = (require 'js-beautify').js_beautify
coffeescript = require 'coffee-script'
stacktrace = require 'stack-trace'
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

readFileLine = (filename, line) ->
  body = fs.readFileSync(filename).toString()

  if filename[-6 ...] == 'coffee'
    return coffeescript.compile(body).split('\n')[line - 1]
  else
    return body.split('\n')[line - 1]

parseMiddlewareName = (callsite) ->
  line = readFileLine callsite.getFileName(), callsite.getLineNumber()
  line.match(/use\((.+)?/)[1]
  .replace /\);$/, ''
  .replace /\{$/, ''
  .replace /\s+$/, ''

module.exports = (options = {}) ->
  {port, ip} = options

  middleware_source:
    'Source Code': 'name'

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
            name: if layer.name != '<anonymous>' then layer.name else layer.handle.middleware_name
            source: funcSource layer.handle

    reflectRouter app._router

    _.extend app_info,
      empty: false
      settings: app.settings
      middleware: middlewares
      router: routers

  injectExpress =  ->
    original_use = express.Router.use

    express.Router.use = ->
      callsite = _.first _.filter stacktrace.get()[1 ...], (c) ->
        return c.getFileName()[-6 ...] == 'coffee'

      if callsite
        functions = _.filter arguments, _.isFunction
        functions = _.reject functions, (f) -> f.stack

        for func in functions
          func.middleware_name = parseMiddlewareName callsite

      original_use.apply @, arguments

  createExplorerServer = ->
    explorer = express()

    explorer.get '/', (req, res) ->
      res.json app_info

    if ip != undefined
      explorer.listen (port ? 1839), ip
    else
      explorer.listen (port ? 1839), '127.0.0.1'

  createExplorerServer()
  injectExpress()

  return (req, res, next) ->
    if app_info.empty
      reflectApp req.app

    next()
