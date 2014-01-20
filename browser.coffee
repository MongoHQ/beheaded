Phantom = require("phantom")
URL = require("url")
assert = require("chai").assert
Q = require("q")
debug = require("debug")("browser")
_ = require("lodash")
Assert = require("./assert")
{EventEmitter2} = require("eventemitter2")

MOUSE_EVENT_NAMES = ["mousedown", "mousemove", "mouseup", "click"]
MAX_WAIT = 2 * 1000 # 2s

class Browser extends EventEmitter2
  @default:
    site: "http://localhost:3000"
    driver: "phantomjs"

  constructor: (@options = {}, @driverArgs...)->
    _.defaults(@options, Browser.default)
    debug "instantiating, with options", @options, (@driverArgs.length && @driverArgs || "")
    @assert = new Assert(@)
    @Driver = require("./drivers")[@options.driver]
    {@protocol, @hostname, @port} = URL.parse(@options.site)
    @reset()

  reset: ->
    # if @pendingRequests
    #   for id, request of @pendingRequests
    #     console.log request
    #     request["abort()"]()
    @network = {}
    @pendingRequests = {}
    @loading = false
    @driverReady = false
    @status = null
    @redirected = false

  getDriver: (callback)->
    debug "getDriver"
    return process.nextTick(callback.bind(this, null, @driver)) if @driver
    @Driver.create @driverArgs, (error, @driver)=>
      @listenToDriver()
      callback.call(this, error, @driver)

  listenToDriver: ->
    @driver.on "load:started", @_handleLoadStarted
    @driver.on "load:finished", @_handleLoadFinished
    @driver.on "console:message", @_handleConsole
    @driver.on "resource:requested", @_handleRequest
    @driver.on "resource:received", @_handleResponse

  makeUrl: (url)->
    return "#{@protocol}//#{@hostname}:#{@port}#{url}" if @options.site
    return url

  visit: (url, callback)->
    full_url = @makeUrl(url)
    debug "visit", full_url
    {promise, callback} = @_wrapCallback(callback)
    @reset()
    @getDriver (error, driver)->
      driver.once "ready", => @driverReady = true
      catchInitialResponse = (resp)=>
        if resp.url == full_url
          @status = resp.status
          if "#{@status}".indexOf "3" == 0
            @redirected = true
          @removeListener "response", catchInitialResponse
      @on "response", catchInitialResponse
      driver.visit full_url, (error)=>
        return callback(error) if error
        @wait(callback)
    return promise

  wait: (callback)->
    if !@isLoading() && !@isWaiting() && @driverIsReady()
      setImmediate(callback)
    else
      _.delay =>
        @wait(callback)
      , 10 # delay 10 ms before retrying.

  isWaiting: ->
    @hasPendingRequests()

  isLoading: ->
    !!@loading

  driverIsReady: ->
    !!@driverReady

  hasPendingRequests: ->
    Object.keys(@pendingRequests).length

  _handleLoadStarted: =>
    @loading = true
    debug "loading started"

  _handleLoadFinished: =>
    @loading = false
    debug "loading finished"

  _handleRequest: (data, request)=>
    request.data = data
    @emit "request", data
    # if ext_matches = data.url.match(/\.(.+)$/)
    #   @emit "request:#{ext_matches[1]}", data
    @network[data.id] = @pendingRequests[data.id] = request
    debug "##{data.id}", data.method, data.url

  _handleResponse: (response)=>
    @emit "response", response
    delete @pendingRequests[response.id]
    if @network[response.id]
      for k, v of response
        @network[response.id].data[k] = v
    debug "##{response.id}", response.data && response.data.method || "N/A", response.url, "=> #{response.status || response.stage}"

  _handleConsole: (msg, lineNum, sourceId)->
    console.log "#{msg}"

  _handleResourceError: (resError)->
    console.log('Unable to load resource (#' + resError.id + 'URL:' + resError.url + ')')
    console.log('Error code: ' + resError.errorCode + '. Description: ' + resError.errorString)

  _handleResourceTimeout: (request)->
    console.log "request timeout ##{request.id}", JSON.stringify(request)

  text: (selector, callback)->
    debug "text", selector
    @evaluate (selector)->
      if document.documentElement
        Array.prototype.map.call(document.querySelectorAll(selector || "html"), (el)-> el.textContent)
          .join("").trim().replace(/\s+/g, " ")
      else
        return ""
    , callback, selector

  value: (selector, callback)->
    debug "value", selector
    @evaluate (selector)->
      field = document.querySelector(selector)
      if field
        if field.isContentEditable
          return field.innerHTML
        else
          return field.value
      
      # Use field name (case sensitive).
      for field in document.querySelectorAll("input[name],textarea[name],select[name]")
        if field.getAttribute("name") == selector
          return field.value
    
    , callback, selector

  _wrapCallback: (callback, timeout = 1)->
    deferred = Q.defer()
    return {
      promise: deferred.promise
      callback: (error, result)=>
        if error && error instanceof Error
          deferred.reject(error)
          callback(error) if callback
        else
          if arguments.length == 1
            result = error
          _.delay ->
            deferred.resolve(result)
            callback(null, result) if callback
          , timeout
    }


  fill: (selector, text, cb)->
    debug "fill \"#{selector}\" with \"#{text}\""
    @evaluate (selector, text)->
      field = document.querySelector(selector)
      if field
        if field.isContentEditable
          field.innerHTML = text
        else
          field.value = text
        return

      # Use field name (case sensitive).
      for field in document.querySelectorAll("input[name],textarea[name],select[name]")
        if field.getAttribute("name") == selector
          return field.value = text

    , cb, selector, text

  evaluate: (timeout, fn, cb, args...)->
    debug "evaluate"
    if _.isFunction(timeout)
      [timeout, fn, cb, args] = [1, timeout, fn, [cb].concat(args)]
    if _.isFunction(cb)
      {promise, callback} = @_wrapCallback(cb, timeout)
    else
      {promise, callback} = @_wrapCallback((->), timeout)

    unless cb
      args = _.compact(obj for obj in args when obj != cb)
    
    @getDriver (error, driver)=>
      return callback(error) if error
      @wait ->
        try
          driver.evaluate.apply(driver, [fn, callback.bind(null, null)].concat(args))
        catch error
          callback(error)

    return promise

  location: (callback)->
    debug "location"
    @evaluate ->
      obj = {}
      obj[key] = window.location[key] for key in Object.keys(window.location)
      return obj
    , callback


  click: (selector, callback)=>
    @evaluate 50, (selector)->
      link = document.querySelector(selector)
      return link.click() if link
      for link in document.querySelectorAll("body a, body button")
        link.click() if link.textContent.trim() == selector
    , callback, selector

  pressButton: (selector, callback)=>
    debug "pressButton \"#{selector}\""
    @click.apply(@, arguments)

  clickLink: (selector, callback)=>
    debug "clickLink \"#{selector}\""
    @click.apply(@, arguments)

  classes: (selector, callback)->
    @evaluate (selector)->
      document.querySelector(selector).className.split(/\s+/)
    , callback, selector

  # waitFor: (criterion, callback)->
  #   if _.isNumber(criterion)
  #     _.delay callback.bind(this), criterion
  #   else if _.isFunction(criterion)
  #     maxTimeout = setTimeout ->
  #       callback(new Error("Browser was still waiting after #{MAX_WAIT}ms"))
  #     , MAX_WAIT

  #     isDone = false

  #     done = (error, isTrue)->
  #       if isDone = !!isTrue && !error
  #         clearTimeout(maxTimeout)
  #         callback(error, isTrue)
  #       return isDone

  #     retry = ->
  #       criterion (error, result)->
  #         unless done(error, result)
  #           setImmediate retry
  #     retry()

  # _findRequest: (method, callback)->
  #   requests = _.where(_.values(@_network), method: method)
  #   _.find(requests, callback)

  # _hasPendingRequests: ->
  #   Object.keys(@_pendingRequests).length

  # _request: (method, url, status, cb)->
  #   {promise, callback} = @_wrapCallback(cb)
  #   @wait =>
  #     req = @_findRequest method, (request)->
  #       if request.url.indexOf(url) != -1
  #         true unless status
  #         request.status == status
  #     if req
  #       setImmediate callback.bind(null, null, req)
  #     else
  #       errorText = "Could not find request #{method} #{url}"
  #       errorText += " with status #{status}" if status
  #       setImmediate callback.bind(null, new Error(errorText))
  #   return promise

  deleteCookies: (callback)->
    debug "delete all cookies"
    {promise, callback} = @_wrapCallback(callback)
    if @driver
      @wait => @driver.deleteCookies(callback)
    else
      setImmediate(callback)
    return promise

  # fire: (selector, eventName, callback)->
  #   unless @page
  #     throw new Error("No page open")
  #   if ~MOUSE_EVENT_NAMES.indexOf(eventName)
  #     eventType = "MouseEvents"
  #   else
  #     eventType = "HTMLEvents"
  #   @evaluate (selector, eventName, eventType)->
  #     target = document.querySelector(selector)
  #     unless target && target.dispatchEvent
  #       throw new Error("No target element (note: call with selector/element, event name and callback)")

  #     event = document.createEvent(eventType)
  #     if eventType == "MouseEvents"
  #       event.initMouseEvent(
  #         eventName,
  #         true, # bubble
  #         true, # cancelable
  #         window, null,
  #         0, 0, 0, 0, # coordinates
  #         false, false, false, false, # modifier keys
  #         0, # button=left
  #         null
  #       )
  #     else
  #       event.initEvent(eventName, true, true)
  #     target.dispatchEvent(event)

  #   , callback, selector, eventName, eventType

  destroy: (callback)->
    debug "destroy"
    if @driver
      @driver.destroy(callback)
    else
      setImmediate(callback)
    delete @driver

module.exports = Browser