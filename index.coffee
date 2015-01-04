{js_beautify: jsBeautify} = require 'js-beautify'
coffeescript = require 'coffee-script'
stacktrace = require 'stack-trace'
js2coffee = require 'js2coffee'
methods = require 'methods'
express = require 'express'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'

formatPath = (path) ->
  unless path
    return '/'

  while path[... 2] == '//'
    path = path[1 ...]

  if path[-1 ...] == '/' and path.length > 1
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
    return formatPath base + format regex
  else
    return '/'

module.exports = (options = {}) ->
  options = _.extend {
    ip: '127.0.0.1'
    port: 1839
    app_root: '.'
    app_excludes: [/^node_modules/]
    coffeescript: true
  }, options

  specification =
    package: {}
    settings: {}
    middlewares: []
    routers: []
    router: {}

  middleware = (req, res, next) ->
    next()

  createExplorerServer = ->
    explorer = express()

    explorer.get '/', (req, res) ->
      res.render __dirname + '/index.jade', specification

    explorer.get '/.json', (req, res) ->
      res.json specification

    explorer.get '/.markdown', (req, res) ->
      res.sendStatus 404

    explorer.use '/assets', express.static __dirname + '/assets'
    explorer.use '/bower_components', express.static __dirname + '/bower_components'

    explorer.listen options.port, options.ip

  injectExpress = ->
    app_root = path.resolve options.app_root

    original =
      use: express.Router.use
      listen: express.application.listen

    express.Router.use = ->
      callsite = _.find stacktrace.get()[1 ...], (site) ->
        filename = site.getFileName()

        return filename[... app_root.length] == app_root and
          _.every options.app_excludes, (exclude) ->
            return !exclude.test filename[app_root.length + 1 ...]

      if callsite
        _.chain(arguments)
        .filter _.isFunction
        .reject (func) -> func.stack
        .each (func) ->
          _.extend func,
            middleware_name: parseMiddlewareName callsite

      original.use.apply @, arguments

    express.application.listen = ->
      reflectExpress @
      original.listen.apply @, arguments

  readPackage = ->
    filename = path.join path.resolve(options.app_root), 'package.json'

    fs.exists filename, (exists) ->
      if exists
        fs.readFile filename, (err, body) ->
          unless err
            specification.package = JSON.parse body

  formatSource = (func) ->
    if options.coffeescript
      source = 'f = ' + func.toString()

      source = js2coffee.build source,
        single_quotes: true

      return source[4 ...]
    else
      return jsBeautify func.toString()

  readFileLine = (filename, line) ->
    body = fs.readFileSync(filename).toString()

    if filename[-6 ...] == 'coffee'
      return coffeescript.compile(body).split('\n')[line - 1]
    else
      return body.split('\n')[line - 1]

  parseMiddlewareName = (callsite) ->
    line = readFileLine callsite.getFileName(), callsite.getLineNumber()

    if options.coffeescript
      return line.match(/use\((.+)?/)[1]
      .replace /\);$/, ''
      .replace /\{$/, ''
      .replace /\s+$/, ''
    else
      return line

  reflectRouter = (router, base = '/') ->
    for layer in router.stack
      if layer.route
        for route_layer in layer.route.stack
          specification.routers.push
            path: formatPath base + layer.route.path
            method: route_layer.method.toUpperCase()
            source: formatSource route_layer.handle
            handle: route_layer.handle

      else if layer.handle.stack
        reflectRouter layer.handle, formatPathRegex(layer.regexp, base)

      else
        specification.middlewares.push
          path: formatPathRegex layer.regexp, base
          name: if layer.name != '<anonymous>' then layer.name else layer.handle.middleware_name
          source: formatSource layer.handle
          handle: layer.handle

  organizeRouter = ->
    _.extend specification,
      router: {}

#    onlyMethodChild = (ref) ->
#      return _.isEmpty _.reject _.keys(ref), (key) ->
#        return key.toLowerCase() in methods

    for router in specification.routers
      path_parts = _.compact router.path.split '/'
#      path_parts = ['/'] if _.isEmpty path_parts
      ref = specification.router

      for part in path_parts
        ref[part] ?= {}
        ref = ref[part]

#      unless onlyMethodChild ref
#        ref['/'] ?= {}
#        ref = ref['/']

      ref[router.method] ?=
        routers: []

      ref[router.method].routers.push _.extend router,
        name: router.handle.name
        middleware_name: router.handle.middleware_name

  reflectExpress = (app) ->
    _.extend specification,
      settings: app.settings
      middlewares: []
      routers: []

    reflectRouter app._router
    organizeRouter()

  createExplorerServer()
  injectExpress()
  readPackage()

  return _.extend middleware,
    reflectExpress: reflectExpress
