module.exports = function(){
  if (!HTMLElement.prototype.click) {
    HTMLElement.prototype.click = function() {
      var ev = document.createEvent('MouseEvent');
      ev.initMouseEvent(
          'click',
          /*bubble*/true, /*cancelable*/true,
          window, null,
          0, 0, 0, 0, /*coordinates*/
          false, false, false, false, /*modifier keys*/
          0/*button=left*/, null
      );
      this.dispatchEvent(ev);
    }
  }
}