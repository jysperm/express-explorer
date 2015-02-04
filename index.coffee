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
    stacks: []

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

    explorer.get '/.md', (req, res) ->
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
        .each (func, i) ->
          handle_name = parseHandleName callsite, i

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

  reflectExpress = (app) ->
    parseRouter = (router, base = '/') ->
      stacks = []

      handleName = (handle) ->
        if handle.name and handle.name != '<anonymous>'
          return handle.name
        else
          return handle.handle_name

      for layer in router.stack
        if layer.route
          for route_layer in layer.route.stack
            stacks.push
              type: 'route'
              path: formatPath base + layer.route.path
              method: route_layer.method.toUpperCase()
              source: formatSource route_layer.handle
              handle: route_layer.handle
              handle_seq: route_layer.handle.handle_seq
              handle_name: handleName route_layer.handle

        else if layer.handle.stack
          router = parseRouter layer.handle, formatPathRegex(layer.regexp, base)

          stacks.push _.extend router,
            type: 'router'

        else
          stacks.push
            type: 'middleware'
            path: formatPathRegex layer.regexp, base
            source: formatSource layer.handle
            handle: layer.handle
            handle_seq: layer.handle.handle_seq
            handle_name: handleName layer.handle

      return stacks

    _.extend specification,
      settings: app.settings
      stacks: parseRouter app._router

  readPackage specification, options
  createExplorerServer()
  injectExpress()

  return _.extend collector,
    reflectExpress: reflectExpress
