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
      promise = @browser.text selector, (error, textContent)->
        return done(error) if error
        return done(new Error("DOM Node with selector \"#{selector}\" was not found.")) unless textContent
        try
          assert.equal trim(textContent), text, message
          done()
        catch error
          done(error)
      return promise

  location: (location)->
    (done)=>
      debug "location expected to equal", location
      result = null
      @browser.wait (callback)=>
        @browser.location (error, winLocation)->
          return callback(error) if error
          if typeof location == "regex"
            result = location.test(winLocation.href)
          else if typeof location == "string"
            result = winLocation.href == location
          else
            for key, value of location
              result = winLocation[key] == value
        if result
          callback(null, result)
        else
          callback()
      , (error, result)->
        console.log "LOCATION WAIT CALLBACK"
        console.log arguments
        assert(result) unless error
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
      , (error, hasFocus)->
        assert hasFocus, "expected #{selector} to have focus" unless error
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