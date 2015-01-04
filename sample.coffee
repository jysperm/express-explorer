expressExplorer = (require './index')()
expressSession = require 'express-session'
cookieParser = require 'cookie-parser'
express = require 'express'

session = ->
  return expressSession
    secret: 'expressSession'
    resave: false,
    saveUninitialized: true

authenticate = (req, res, next) ->
  next()

account = do ->
  router = express.Router()

  router.get '/', (req, res) ->
    res.redirect '/account/login'

  router.get '/login', (req, res) ->
    res.send 'Login'

  router.post '/login', (req, res) ->
    res.send 'POST Login'

  router.get '/dashboard', authenticate, (req, res) ->
    res.send 'Dashboard'

app = express()

app.use expressExplorer
app.use cookieParser()
app.use session()

app.get '/', (req, res) ->
  res.send 'Index'

app.use '/account', account

app.listen 3000
