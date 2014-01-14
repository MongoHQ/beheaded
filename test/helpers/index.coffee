require("mocha-as-promised")()
Chai = require("chai")
Browser = require("../../index")

Browser.default.site = "http://localhost:3003"

Chai.use require("chai-as-promised")

module.exports =
  assert:  Chai.assert
  server:  require("./server")
  Browser: Browser