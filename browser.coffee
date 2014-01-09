Phantom = require("phantom")
URL = require("url")
assert = require("chai").assert
Q = require("q")
debug = require("debug")("browser")
_ = require("lodash")
Async = require("async")
extensions = require("./extensions")
{EventEmitter} = require("events")
Assert = require("./assert")

MOUSE_EVENT_NAMES = ["mousedown", "mousemove", "mouseup", "click"]

class Browser extends EventEmitter
  _network: {}
  _pendingRequests: {}

  @default:
    site: "http://localhost:3000"

  constructor: (@options = {})->
    _.defaults(@options, Browser.default)
    debug "creating browser with options", @options
    @assert = new Assert(@)
    @_loading = false
    if @options.site
      {@hostname, @port, @protocol} = URL.parse(@options.site)

  _phantom: (callback)->
    return process.nextTick(callback.bind(this, @phantom)) if @phantom
    debug "instantiating phantomjs"
    if @options.args
      return Phantom.create.apply(null, @options.args.concat([@_onPhantomCreation(callback)]))
    Phantom.create(@_onPhantomCreation(callback))

  _onPhantomCreation: (callback)=>
    (@phantom)=>
      callback.call(this, @phantom)

  _sugarizePage: (callback=(->))=>
    fns = (@evaluate.bind(this, extensions[ext]) for ext in ["bind", "click"])
    Async.parallel fns, ->
      debug "sugarized"
      callback()

  _page: (callback)->
    return process.nextTick(callback.bind(this, null, @page)) if @page
    debug "creating a page within phantomjs"
    @_phantom (phantom)=>
      debug "got phantomjs instance, creating page..."
      phantom.createPage (@page)=>
        debug "got page instance, setting options"
        @_sugarizePage =>
          debug "page sugarized"
          @page.set "onLoadStarted", @_handleLoadStarted
          @page.set "onLoadFinished", @_handleLoadFinished
          @page.set "onResourceRequested", @_handleRequest
          @page.set "onResourceReceived", @_handleResponse
          @page.set "onConsoleMessage", @_handleConsole
          debug "page instantiated"
          callback(null, @page)
  
  _handleLoadStarted: =>
    @_loading = true

  _handleLoadFinished: =>
    @_loading = false

  _url: (url)->
    return "#{@protocol}//#{@hostname}:#{@port}#{url}" if @options.site
    return url

  _handleRequest: (data, request)=>
    @emit "request", data
    @_network[data.id] = @_pendingRequests[data.id] = data
    debug("##{data.id}", data.method, data.url)

  _handleResponse: (response)=>
    @emit "response", response
    delete @_pendingRequests[response.id]
    for k, v of response
      @_network[response.id][k] = v
    debug("##{response.id}", @_network[response.id].method, response.url, "=> #{response.status}")

  _handleConsole: (msg, lineNum, sourceId)->
    console.log "#{msg}"

  visit: (url, callback)->
    full_url = @_url(url)
    debug "visit #{full_url}"
    {promise, callback} = @_wrapCallback(callback)
    @_page (error, page)=>
      sugarizeBeforeFirstJS = (req)=>
        if /\.js$/.test(req.url)
          @_sugarizePage =>
            debug("INJECTED BEFORE JS LOADED?")
          @removeListener "request", sugarizeBeforeFirstJS
      @on "request", sugarizeBeforeFirstJS
      page.open full_url, (@status)=>
        debug "visit #{full_url} => #{@status}"
        callback(null)
    return promise

  evaluate: (fn, callback, args...)->
    {promise, callback} = @_wrapCallback(callback.bind(null, null))
    @_page (error, page) =>
      page.evaluate.apply(page, [fn, callback].concat(args || []))
    return promise

  text: (selector, callback)->
    {promise, callback} = @_wrapCallback(callback)
    @evaluate (selector)->
      if document.documentElement
        Array.prototype.map.call(document.querySelectorAll(selector || "html"), (el)-> el.textContent)
          .join("").trim().replace(/\s+/g, " ")
      else
        return ""
    , callback, selector
    return promise

  _wrapCallback: (callback, timeout = 0)->
    deferred = Q.defer()
    return {
      promise: deferred.promise
      callback: (error, result)=>
        if error
          deferred.reject(error)
          callback(error) if callback
        else
          setTimeout =>
            @wait (callback)=>
              callback(null, !@_loading && !@_isWaiting())
            , (waitError)->
              deferred.resolve(result)
              callback(null, result) if callback
          , timeout
    }


  fill: (selector, text, callback)->
    debug "fill \"#{selector}\" with \"#{text}\""
    {promise, callback} = @_wrapCallback(callback)
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

    , callback, selector, text
    return promise

  location: (callback)->
    {promise, callback} = @_wrapCallback(callback)
    @evaluate ->
      obj = {}
      for k, v of window.location
        obj[k] = v
      return obj
    , callback
    return promise


  click: (selector, callback)=>
    {promise, callback} = @_wrapCallback(callback)
    # @fire selector, "click", callback
    @evaluate (selector)->
      link = document.querySelector(selector)
      if link
        return link.click()
      for link in document.querySelectorAll("body a, body button")
        if link.textContent.trim() == selector
          return link.click()
    , callback, selector
    return promise

  pressButton: (selector, callback)=>
    debug "pressButton \"#{selector}\""
    @click.apply(@, arguments)

  clickLink: (selector, callback)=>
    debug "clickLink \"#{selector}\""
    @click.apply(@, arguments)

  classes: (selector, callback)=>
    {promise, callback} = @_wrapCallback(callback)
    @evaluate (selector)->
      document.querySelector(selector).className.split(/\s+/)
    , callback, selector
    return promise

  wait: (fn, callback=(->), maxWait = 2000)->
    maxTimeout = setTimeout ->
      callback(new Error("Browser was still waiting after #{maxWait}ms"))
    , maxWait

    isDone = false

    done = (error, result)->
      # console.log "done", result, !!result
      if isDone = !!result && !error
        clearTimeout(maxTimeout)
        callback(error, result)
      return isDone

    retry = ->
      fn (error, result)->
        unless done(error, result)
          setImmediate retry
    retry()

    return @

  _findRequest: (method, callback)->
    requests = _.where(_.values(@_network), method: method)
    _.find(requests, callback)

  _isWaiting: ->
    @_hasPendingRequests()

  _hasPendingRequests: ->
    Object.keys(@_pendingRequests).length

  _request: (method, url, status, callback)->
    {promise, callback} = @_wrapCallback(callback)
    @wait (done)=>
      req = @_findRequest method, (request)->
        if request.url.indexOf(url) != -1
          true unless status
          request.status == status
      if req
        setImmediate done.bind(null, null, req)
      else
        setImmediate done
    , callback
    return promise

  deleteCookies: (done)->
    @_phantom (phantom)->
      phantom.clearCookies(done)

  fire: (selector, eventName, callback)->
    unless @page
      throw new Error("No page open")
    if ~MOUSE_EVENT_NAMES.indexOf(eventName)
      eventType = "MouseEvents"
    else
      eventType = "HTMLEvents"
    @evaluate (selector, eventName, eventType)->
      target = document.querySelector(selector)
      unless target && target.dispatchEvent
        throw new Error("No target element (note: call with selector/element, event name and callback)")

      event = document.createEvent(eventType)
      if eventType == "MouseEvents"
        event.initMouseEvent(
          eventName,
          true, # bubble
          true, # cancelable
          window, null,
          0, 0, 0, 0, # coordinates
          false, false, false, false, # modifier keys
          0, # button=left
          null
        )
      else
        event.initEvent(eventName, true, true)
      target.dispatchEvent(event)

    , callback, selector, eventName, eventType

module.exports = Browser