debug = (require 'debug') 'express-explorer'
stacktrace = require 'stack-trace'
methods = require 'methods'
express = require 'express'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'

utils = require './utils'

{addToSet, isStartWith, formatPath, formatPathRegex} = utils
{readPackage, parseHandleName} = utils

module.exports = (options = {}) ->
  options = _.extend {
    ip: '127.0.0.1'
    port: 1839
    app_root: '.'
    app_excludes: [/^node_modules/]
    coffeescript: true
  }, options

  formatSource = (func) ->
    return utils.formatSource func, options

  specification =
    package: {}
    settings: {}
    middlewares: []
    routers: []
    router: {}

  collector = (req, res, next) ->
    next()

  createExplorerServer = ->
    {port, ip} = options
    explorer = express()
    explorer.set 'views', __dirname + '/views'

    markdownGenerator = ->

    fs.readFile __dirname + '/views/markdown.md', (err, body) ->
      markdownGenerator = _.template body.toString()

    explorer.get '/', (req, res) ->
      res.render 'index.jade', specification

    explorer.get '/.json', (req, res) ->
      res.json specification

    explorer.get '/.markdown', (req, res) ->
      res.header 'Content-Type', 'text/markdown'
      res.send markdownGenerator specification

    explorer.use '/assets', express.static __dirname + '/assets'
    explorer.use '/bower_components', express.static __dirname + '/bower_components'

    explorer.listen port, ip, ->
      debug "createExplorerServer: started at #{ip}:#{port}"

  injectExpress = ->
    app_root = path.resolve options.app_root

    original =
      use: express.Router.use
      listen: express.application.listen

    injectHandle = (callsites, args) ->
      callsite = _.find callsites[1 ...], (site) ->
        filename = site.getFileName()

        return filename[... app_root.length] == app_root and
            _.every options.app_excludes, (exclude) ->
              return !exclude.test filename[app_root.length + 1 ...]

      if callsite
        _.chain args
        .filter _.isFunction
        .reject (func) -> func.stack
        .each (func, i) ->
          handle_name = parseHandleName callsite, i

          unless handle_name in ['function(req, res)', 'function(unknown)']
            func.is_middleware = true

          _.extend func,
            handle_seq: i
            handle_name: handle_name

    express.Router.use = ->
      injectHandle stacktrace.get(), arguments
      original.use.apply @, arguments

    express.application.listen = ->
      reflectExpress @
      original.listen.apply @, arguments

    methods.concat(['all']).forEach (method) ->
      original[method] = express.Router[method]

      express.Router[method] = ->
        injectHandle stacktrace.get(), arguments
        original[method].apply @, arguments

  reflectRouter = (router, base = '/') ->
    for layer in router.stack
      if layer.route
        for route_layer in layer.route.stack
          specification.routers.push
            path: formatPath base + layer.route.path
            method: route_layer.method.toUpperCase()
            source: formatSource route_layer.handle
            handle: route_layer.handle
            is_middleware: route_layer.handle.is_middleware

      else if layer.handle.stack
        reflectRouter layer.handle, formatPathRegex(layer.regexp, base)

      else
        specification.middlewares.push
          path: formatPathRegex layer.regexp, base
          handle_name: if layer.name != '<anonymous>' then layer.name else layer.handle.handle_name
          source: formatSource layer.handle
          handle: layer.handle
          is_middleware: layer.handle.is_middleware

  organizeRouter = ->
    _.extend specification,
      router: {}

    onlyMethodChild = (ref) ->
      return _.isEmpty _.reject _.keys(ref), (key) ->
        return key.toLowerCase() in methods

    resolveRootPath = (ref) ->
      return if onlyMethodChild ref

      for method in methods
        method = method.toUpperCase()

        if ref[method]
          ref['/'] ?= {}
          ref['/'][method] = ref[method]
          delete ref[method]

      for k, v of ref
        resolveRootPath v

    for router in specification.routers
      path_parts = _.compact router.path.split '/'
      ref = specification.router

      for part in path_parts
        ref[part] ?= {}
        ref = ref[part]

      ref[router.method] ?= {}

      if router.is_middleware
        ref[router.method].middlewares ?= []
        ref[router.method].middlewares.push router.handle.handle_name
      else
        ref[router.method].routers ?= []
        ref[router.method].routers.push _.extend router,
          handle_name: router.handle.handle_name

      for middleware in specification.middlewares
        unless middleware.path == '/'
          if isStartWith router.path, middleware.path
            ref[router.method].middlewares ?= []
            addToSet ref[router.method].middlewares, middleware.handle_name

    resolveRootPath specification.router

  reflectExpress = (app) ->
    _.extend specification,
      settings: app.settings
      middlewares: []
      routers: []

    reflectRouter app._router
    organizeRouter()

  createExplorerServer()
  injectExpress()
  readPackage specification, options

  return _.extend collector,
    reflectExpress: reflectExpress
