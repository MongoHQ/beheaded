fs = require("fs")
path = require("path")

fs.readdirSync(__dirname).forEach (filename) ->
  load = ->
    require "./" + name
  name = path.basename(filename, ".coffee")
  return if name == "index"
  exports.__defineGetter__ name, load
