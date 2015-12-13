{Emitter} = require 'atom'
_ = require 'underscore-plus'

maxLength = 120

module.exports =
class TodoModel
  constructor: (match, {plain} = []) ->
    return _.extend(this, match) if plain
    @handleScanMatch match

  getAllKeys: ->
    atom.config.get('todo-show.showInTable') or ['Text']

  get: (key = '') ->
    return value if value = @[key.toLowerCase()]
    @text or 'No details'

  getMarkdown: (key = '') ->
    return '' unless value = @[key.toLowerCase()]
    switch key
      when 'All' then " #{value}"
      when 'Text' then " #{value}"
      when 'Type' then " __#{value}__"
      when 'Range' then " _:#{value}_"
      when 'Line' then " _:#{value}_"
      when 'Regex' then " _'#{value}'_"
      when 'File' then " [#{value}](#{value})"
      when 'Tags' then " _#{value}_"

  getMarkdownArray: (keys) ->
    for key in keys or @getAllKeys()
      @getMarkdown(key)

  contains: (string = '') ->
    for key in @getAllKeys()
      break unless item = @get(key)
      return true if item.indexOf(string) isnt -1
    false

  handleScanMatch: (match) ->
    matchText = match.text or match.all or ''

    # Strip out the regex token from the found annotation
    # not all objects will have an exec match
    while (_matchText = match.regexp?.exec(matchText))
      matchText = _matchText.pop()

    # Strip common block comment endings and whitespaces
    matchText = matchText.replace(/(\*\/|\?>|-->|#>|-}|\]\])\s*$/, '').trim()

    # Extract todo tags
    match.tags = (while (tag = /\s*#(\w+)[,.]?$/.exec(matchText))
      break if tag.length isnt 2
      matchText = matchText.slice(0, -tag.shift().length)
      tag.shift()
    ).sort().join(', ')

    # Truncate long match strings
    if matchText.length >= maxLength
      matchText = "#{matchText.substr(0, maxLength - 3)}..."

    # Make sure range is serialized to produce correct rendered format
    match.position = [[0,0]] unless match.position and match.position.length > 0
    if match.position.serialize
      match.range = match.position.serialize().toString()
    else
      match.range = match.position.toString()

    match.text = matchText || "No details"
    match.line = (parseInt(match.range.split(',')[0]) + 1).toString()
    match.file ?= atom.project.relativize(match.path)

    _.extend(this, match)
