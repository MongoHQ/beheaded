fs = require("fs")
path = require("path")

fs.readdirSync(__dirname).forEach (filename) ->
  load = ->
    require "./" + name
  name = path.basename(filename, ".js")
  return if name == "index.coffee"
  exports.__defineGetter__ name, load
