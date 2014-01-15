# Beheaded

## What is it?

Headless browser testing tool for node.js using PhantomJS.

- Promises everywhere (they're neat)
- PhantomJS (higher fidelity with a browser)

## Usage

```
npm install beheaded
```

It's recommended you use [mocha-as-promised](https://github.com/domenic/mocha-as-promised) and [chai-as-promised](https://github.com/domenic/chai-as-promised/) since the asynchronous nature of PhantomJS makes the tests look a bit funky.

## Example

Feel free to look at the [tests](https://github.com/MongoHQ/beheaded/blob/master/test/browser_test.coffee)

```coffee
Browser = require("beheaded")
server = require("./helpers/server") # You probably need some server to test.
Chai = require("chai")
Chai.use require("chai-as-promised")
assert = Chai.assert

require("mocha-as-promised")()

describe "Browser", ->

  browser = null
  before ->
    browser = new Browser()
  before server.ready

  describe "visit", ->
    before (done)-> browser.visit "/", done

    # The browser instance holds the current page's status
    it "succeeds", ->
      assert.equal 200, browser.status

    # `browser.location` returns a promise, use `assert.eventually`
    # from chai-as-promised to test that out.
    it "is on the correct page", ->
      assert.eventually.propertyVal browser.location(), "href", "http://localhost:3001/"
```