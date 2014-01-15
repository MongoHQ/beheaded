{ assert, server, Browser } = require("../helpers")
Driver = require("../../drivers/phantomjs")

describe "PhantomJS Driver", ->
  # browser = null
  # before ->
  #   browser = new Browser(driver: "phantomjs")
  # before server.ready

  driver = null
  describe "class methods", ->
    describe "create", ->
      before (done)->
        Driver.create [], (error, d)->
          driver = d
          done(error)

      it "has a page", ->
        assert driver.page

  describe "instance methods", ->
    before server.ready
    describe "visit", ->
      it "GETs the url", (done)->
        driver.visit "http://localhost:3003", done

  after (done)->
    driver.destroy(done)