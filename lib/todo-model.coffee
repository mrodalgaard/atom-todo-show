{Emitter} = require 'atom'
_ = require 'underscore-plus'

module.exports =
class TodoModel
  constructor: (match) ->
    @maxLength = 120
    @handleScanMatch match

  handleScanMatch: (match) ->
    matchText = match.text || match.all

    # Strip out the regex token from the found annotation
    # not all objects will have an exec match
    while (_matchText = match.regexp?.exec(matchText))
      matchText = _matchText.pop()

    # Extract todo tags
    match.tags = (while (tag = /\s#(\w+)[,.]?$/.exec(matchText))
      break if tag.length isnt 2
      matchText = matchText.slice(0, tag.shift().length * -1)
      tag.shift()
    ).sort().join(', ')

    # Strip common block comment endings and whitespaces
    matchText = matchText.replace(/(\*\/|\?>|-->|#>|-}|\]\])\s*$/, '').trim()

    # Truncate long match strings
    if matchText.length >= @maxLength
      matchText = "#{matchText.substr(0, @maxLength - 3)}..."

    # Make sure range is serialized to produce correct rendered format
    # See https://github.com/mrodalgaard/atom-todo-show/issues/27
    match.position = [[0,0]] unless match.position and match.position.length > 0
    if match.position.serialize
      match.range = match.position.serialize().toString()
    else
      match.range = match.position.toString()

    match.text = matchText || "No details"
    match.line = parseInt(match.range.split(',')[0]) + 1
    match.file ?= atom.project.relativize(match.path)

    _.extend(this, match)
