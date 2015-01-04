## express-explorer
Generate API document from express meta data.

Usages:

    expressExplorer = (require 'express-explorer')()

    app = express()
    app.use expressExplorer
    app.use otherMiddlewaresOrRouters
    app.listen 3000

Open <http://127.0.0.1:1839> to view API document.

### Options

    expressExplorer = (require 'express-explorer')
      ip: '127.0.0.1'
      port: 1839
      app_root: '.'
      app_excludes: [/^node_modules/]
      coffeescript: true

* `ip` only listen `127.0.0.1` by default
* `port` 1839 by default
* `app_root` default to current directory
* `app_excludes`
* `coffeescript`

### API

* reflectExpress(app)

### Explorer Web API
<http://127.0.0.1:1839> by Default.

* `/` HTML Version
* `/.json` JSON Version
* `/.markdown` Markdown Version

### 已知问题

* 必须在使用 express 的任何函数之前实例化 expressExplorer, 以便向 express 注入代码
* 必须在调用 app.listen 之前添加所有的路由和中间件，因为 express-explorer 会在 app.listen 时收集中间件信息
