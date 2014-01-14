_ = require("lodash")
{ assert } = require("chai")
debug = require("debug")("browser:assert")

trim = (text)->
  text.trim().replace(/(\r|\n+)/g, " ")

class Assert
  constructor: (@browser)->

  text: (selector, text, message)->
    (done)=>
      debug """text from "#{selector}" expected to equal "#{text}" """
      @browser.text selector, (error, textContent)->
        return done(error) if error
        return done(new Error("DOM Node with selector \"#{selector}\" was not found.")) unless textContent
        try
          assert.equal textContent, text, message
          done()
        catch error
          done(error)

  location: (location)->
    (done)=>
      debug "location expected to equal", location
      @browser.location (error, winLocation)->
        return done(error) if error
        if typeof location == "regex"
          result = location.test(winLocation.href)
        else if typeof location == "string"
          result = winLocation.href == location
        else
          for key, value of location
            result = winLocation[key] == value
      try
        assert(result, "window.location did not match #{location}")
        done()
      catch error
        done(error)

  hasNoClass: (selector, c, callback)=>
    (done)=>
      debug """hasNoClass expects "#{selector}" not to have class "#{c}" """
      @browser.classes selector, (error, classes)=>
        assert.notInclude(classes, c)
        done(error)

  hasFocus: (selector, callback)=>
    (done)=>
      debug "hasFocus expected \"#{selector}\" to have focus"
      @browser.evaluate (selector)->
        document.querySelector(selector) == document.activeElement
      , (hasFocus)->
        try
          assert hasFocus, "expected #{selector} to have focus"
          done()
        catch error
          done(error)
      , selector

  get: (url, status)->
    (done)=>
      debug "get expects the browser to GET \"#{url}\" with status #{status}"
      @browser._request("GET", url, status, done)
  
  post: (url, status)->
    (done)=>
      debug "post expects the browser to POST \"#{url}\" with status #{status}"
      @browser._request("POST", url, status, done)

module.exports = Assert