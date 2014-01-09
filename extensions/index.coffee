fs = require("fs")
path = require("path")

fs.readdirSync(__dirname).forEach (filename) ->
  load = ->
    require "./" + name
  name = path.basename(filename, ".js")
  return  if name is "index"
  exports.__defineGetter__ name, load
