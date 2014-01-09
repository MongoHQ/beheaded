express = require("express")
File    = require("fs")
Path    = require("path")


# An Express server we use to test the browser.
server = express()
server.use(express.bodyParser())
server.use(express.cookieParser())


server.get "/", (req, res)->
  res.send """
    <html>
      <head>
        <title>Tap, Tap</title>
      </head>
      <body>
      </body>
    </html>
  """

active = false
server.ready = (callback)->
  if active
    process.nextTick callback
  else
    server.listen 3003, ->
      active = true
      callback()


module.exports = server