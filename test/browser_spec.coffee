{ assert, server, Browser } = require("./helpers")

describe "Browser", ->

  browser = null
  before ->
    browser = new Browser()
  before server.ready

  describe "visit", ->
    before (done)-> browser.visit "/", done

    it "succeeds", ->
      assert.equal 200, browser.status

    it "is on the correct page", ->
      assert.eventually.propertyVal browser.location(), "href", "http://localhost:3003/"


  # describe "evaluate", ->
  #   before (done)-> browser.visit "/", done

  #   it "returns the result of the evaluated function", ->
  #     assert.becomes browser.evaluate(-> document.querySelector("title").textContent), "Tap, Tap"

  #   it "accepts arguments to pass to the evaluate function scope", ->
  #     evalPromise = browser.evaluate (selector, fn)->
  #       document.querySelector(selector)[fn]
  #     , "title", "textContent"
  #     assert.becomes evalPromise, "Tap, Tap"


  # describe "text", ->
  #   before ->
  #     server.get "/has_text", (req, res)->
  #       res.send """
  #       <html>
  #         <head></head>
  #         <body>
  #           <div id="simple-text">This has simple text.</div>
  #           <div id="multi-line-text">This has\nmulti-line\ntext.</div>
  #           <div id="nested-text">This has multiple <span><em>ele</em>ments</span>.</div>
  #         </body>
  #       </html>
  #       """
  #   before (done)-> browser.visit "/has_text", done

  #   it "gets simple text from an element", ->
  #     assert.becomes browser.text("#simple-text"), "This has simple text."

  #   it "gets multi-line text from an element", ->
  #     assert.becomes browser.text("#multi-line-text"), "This has multi-line text."

  #   it "gets nested text from an element", ->
  #     assert.becomes browser.text("#nested-text"), "This has multiple elements."

  #   it "gets the whole text of the page if no selector is specified", ->
  #     assert.becomes browser.text(), "This has simple text. This has multi-line text. This has multiple elements."


  # describe "location", ->
  #   before ->
  #     server.get "/longer/path", (req, res)-> res.send("<html></html>")
    
  #   before (done)-> browser.visit "/longer/path?some_query=param&and_then=some#with_a_hash", done

  #   it "returns the location keys/values", ->
  #     assert.becomes browser.location(),
  #       hash: "#with_a_hash"
  #       host: "localhost:3003"
  #       hostname: "localhost"
  #       href: "http://localhost:3003/longer/path?some_query=param&and_then=some#with_a_hash"
  #       origin: "http://localhost:3003"
  #       pathname: "/longer/path"
  #       port: "3003"
  #       protocol: "http:"
  #       search: "?some_query=param&and_then=some"

  after (done)->
    browser.destroy(done)
    return