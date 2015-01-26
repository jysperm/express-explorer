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
* `app_root` current directory by default
* `app_excludes`
* `coffeescript`

### Debug Mode

    env DEBUG=express-explorer app.coffee

### Explorer Web API
<http://127.0.0.1:1839> by Default.

* `/` HTML Version
* `/.json` JSON Version
* `/.markdown` Markdown Version

### 原理

* 注入 express 用于注册路由的方法(`use`, `get`, `post`, `all` 等), 获取路由信息

### 已知问题

* 必须在使用 express 的任何函数之前实例化 expressExplorer, 以便向 express 注入代码
* 必须在调用 app.listen 之前添加所有的路由和中间件，因为 express-explorer 会在 app.listen 时收集中间件信息

### TODO

* 直接包含所有中间件的源码
* 在 Web 页面上显示有层级的 Endpoints
* 显示路由和中间件前的注释
* 剔除项目目录之外的中间件的源代码
* 支持 param 中间件
* 支持从父路径继承来的中间件
* 支持在运行时捕捉请求和响应信息
* 支持导入导出状态数据
