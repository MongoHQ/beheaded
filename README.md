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

```javascript
var Browser = require("beheaded");
var server = require("./helpers/server"); // You probably need some server to test.
var Chai = require("chai");
Chai.use(require("chai-as-promised"));
var assert = Chai.assert;

require("mocha-as-promised")();

describe("Browser", function(){

  var browser = null;
  before(function(){
    browser = new Browser();
  });
  before(server.ready);

  describe("visit", function(){
    before(function(){
      browser.visit "/"
    });

    // The browser instance holds the current page's status
    it("succeeds", function(){
      assert.equal(200, browser.status);
    });

    // `browser.location` returns a promise, use `assert.eventually`
    // from chai-as-promised to test that out.
    it("is on the correct page", function(){
      assert.eventually.propertyVal(browser.location(), "href", "http://localhost:3001/");
    });
  });
});
```