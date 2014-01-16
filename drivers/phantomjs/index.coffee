Phantom = require("phantom")
debug = require("debug")("browser:phantomjs")
Page = require("./page")
{EventEmitter2} = require("eventemitter2")
_ = require("lodash")

global_phantom = null

class PhantomJS extends EventEmitter2
  constructor: (@phantom)->
    debug "constructed"

  @create: (driverArgs, callback)->
    debug "creating", callback.toString()
    if global_phantom
      return new PhantomJS(global_phantom).createPage(callback)
    try
      Phantom.create.apply null, driverArgs.concat([
        (phantom)=>
          debug "created phantom process"
          global_phantom = phantom
          new PhantomJS(phantom).createPage(callback)
      ])
    catch error
      callback(error)

  createPage: (callback)=>
    debug "createPage"
    try
      @phantom.createPage (page)=>
        debug "created a phantom page instance"
        @page = new Page(page)
        @listenToPage()
        callback(null, @)
    catch error
      callback(error)

  getPage: (callback)->
    debug "getPage"
    return setImmediate(callback.bind(this, null, @page)) if @page
    @createPage (error)->
      callback(error, @page)

  listenToPage: ->
    for name, parsed of Page.eventsMap
      @page.on parsed, @emit.bind(@, parsed)
    @page.on "shimmed", @emit.bind(@, "ready")

  visit: (url, callback)->
    debug "visit", url
    @getPage (error, page)->
      return callback(error) if error
      try
        page.open url, (status)->
          debug "visit", url, "=> #{status}"
          callback()
      catch error
        callback(error)

  evaluate: ->
    debug "evaluate"
    args = arguments
    @getPage (error, page)->
      page.evaluate.apply(page, args)

  deleteCookies: (callback)->
    debug "delete all cookies"
    @phantom.clearCookies(callback)

  destroy: (callback)->
    debug "destroy"
    if @page
      @page.close()
      delete @page
    setImmediate(callback)

module.exports = PhantomJS