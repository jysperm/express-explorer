debug = (require 'debug') 'express-explorer'
{js_beautify: jsBeautify} = require 'js-beautify'
coffeescript = require 'coffee-script'
js2coffee = require 'js2coffee'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'

exports.addToSet = (set, value) ->
  unless value in set
    set.push value

exports.isStartWith = (url, path) ->
  return url[... path.length] == path

exports.formatPath = formatPath = (path) ->
  unless path
    return '/'

  while path[... 2] == '//'
    path = path[1 ...]

  if path[-1 ...] == '/' and path.length > 1
    return path[... -1]

  return path

exports.formatPathRegex = (regex, base = '') ->
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

exports.readPackage = (specification, options) ->
  filename = path.join path.resolve(options.app_root), 'package.json'

  fs.exists filename, (exists) ->
    if exists
      fs.readFile filename, (err, body) ->
        unless err
          specification.package = JSON.parse body

exports.formatSource = (func, options) ->
  if options.coffeescript
    source = '__f = ' + func.toString()

    source = js2coffee.build source,
      single_quotes: true

    return source[6 ...]
  else
    return jsBeautify func.toString()

exports.readFileLine = readFileLine = (filename, line) ->
  body = fs.readFileSync(filename).toString()

  if filename[-6 ...] == 'coffee'
    return coffeescript.compile(body).split('\n')[line - 1]
  else
    return body.split('\n')[line - 1]

exports.parseHandleName = (callsite, seq) ->
  line = readFileLine callsite.getFileName(), callsite.getLineNumber()

  formatLine = (name) ->
    return name
    .replace /('|")[^'"]+('|"),\s+/, ''  # start with path
    .replace /\);$/, ''                  # end with );
    .replace /\{$/, ''                   # end with {
    .replace /\($/, ''                   # end with (
    .replace /\s+$/, ''                  # end with spaces

  name = line.match /[use|post|get|put|delete|patch|head|all|options|del|delete"\]]\((.+)?/
  name = formatLine if name then name[1] else line

  parts = name.split /,(?![^(]*\))/      # `,` not inside `(` and `)`

  if parts[seq]
    name = formatLine parts[seq]
    .replace /^\s+/, ''                  # start with spaces
  else
    name = 'function(unknown)'

  debug "parseHandleName: got `#{name}` from #{seq} of `#{line}`"

  return name

exports.markdownHelpers = (specification) ->
  return _.extend {}, specification,
    headerN: (n) ->
      return ([0 ... n].map -> '#').join ''

    escapeMarkdown: (string) ->
      return string.replace /_/g, '\\_'
