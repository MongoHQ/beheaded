Browser = require("../../index")

Browser.default.site = "http://localhost:3003"

module.exports =
  assert:  require("chai").assert
  server:  require("./server")
  Browser: Browser