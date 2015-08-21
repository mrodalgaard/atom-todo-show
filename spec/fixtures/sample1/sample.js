/**
 * Sample quicksort code
 * TODO: This is the first todo
 *
 * LOONG: Lorem ipsum dolor sit amet, dapibus rhoncus. Scelerisque quam, id ante molestias, ipsum lorem magnis et. A eleifend ipsum. Pellentesque aliquam, proin mollis sed odio, at amet vestibulum velit. Dolor sed, urna integer suspendisse ut a. Pharetra amet dui accumsan elementum, vitae et ac ligula turpis semper donec.
 * LOONG_SpgLE84Ms1K4DSumtJDoNn8ZECZLL+VR0DoGydy54vUoSpgLE84Ms1K4DSumtJDoNn8ZECZLLVR0DoGydy54vUonRClXwLbFhX2gMwZgjx250ay+V0lF7sPZ8AiCVy22sE=SpgL_E84Ms1K4DSumtJDoNn8ZECZLLVR0DoGydy54vUoSpgLE84Ms1K4DSumtJ_DoNn8ZECZLLVR0DoGydy54vUo
 */

var quicksort = function () {
  var sort = function(items) {
    if (items.length <= 1) { return items; }
    var pivot = items.shift(), current, left = [], right = [];
    while(items.length > 0) {
      current = items.shift();
      current < pivot ? left.push(current) : right.push(current);
    }
    return sort(left).concat(pivot).concat(sort(right));
  };

  // TODO: This is the second todo

  return sort(Array.apply(this, arguments));  // DEBUG

  // FIXME: Add more annnotations :)

  // CHANGED one
  // CHANGED: two
  // @CHANGED three
  // @CHANGED: four
  // changed: non-matching tag

  // XXX one
  // XXX: two
  // @XXX three
  // @XXX: four
  //xxx: non-matching tag

  // IDEA one
  // IDEA: two
  // @IDEA three
  // @IDEA: four
  //idea: non-matching tag

  // HACK one
  // HACK: two
  // @HACK three
  // @HACK: four
  //hack: non-matching tag

  // NOTE one
  // NOTE: two
  // @NOTE three
  // @NOTE: four
  //note: non-matching tag

  // REVIEW one
  // REVIEW: two
  // @REVIEW three
  // @REVIEW: four
  //review: non-matching tag

};
