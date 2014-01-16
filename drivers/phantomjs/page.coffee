debug = require("debug")("browser:phantomjs:page")
{EventEmitter2} = require("eventemitter2")
Async = require("async")
extensions = require("./extensions")
_ = require("lodash")

class Page extends EventEmitter2
  @eventsMap:
    onLoadStarted: 'load:started'
    onLoadFinished: 'load:finished'
    onResourceRequested: 'resource:requested'
    onResourceReceived: 'resource:received'
    onConsoleMessage: 'console:message'
    onResourceError: 'resource:error'
    onResourceTimeout: 'resource:timeout'
    onAlert: 'alert'
    onConfirm: 'confirm'
    onPrompt: 'prompt'
    onError: 'error'
    onInitialized: 'initialized'
    onNavigationRequested: 'navigation:requested'
    onPageCreated: 'page:created'
    onUrlChanged: 'url:changed'

  @shims: ["bind", "click"]

  constructor: (@page)->
    for name, parsed of Page.eventsMap
      @page.set name, @emit.bind(@, parsed)
    @reset()
    @on "initialized", @shim
    @on "url:changed", @reset
    # @on "error", (error)-> throw error
    debug "instantiated"

  emit: (name, args...)->
    debug name, args
    super

  reset: =>
    @shimmed = @loading = false

  shim: =>
    debug "shiming with", Page.shims
    return if @shimmed
    fns = _.map Page.shims, (ext)=>
      @evaluate.bind(@, extensions[ext])
    
    Async.parallel fns, =>
      @shimmed = true
      @emit "shimmed"

  open: ->
    debug "open", arguments[0]
    @page.open.apply(@page, arguments)

  close: ->
    debug "close", arguments[0]
    @page.close.apply(@page, arguments)

  evaluate: ->
    debug "evaluate"
    @page.evaluate.apply(@page, arguments)

module.exports = Page