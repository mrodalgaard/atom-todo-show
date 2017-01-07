path = require 'path'

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
    return value if (value = @[key.toLowerCase()]) or value is ''
    @text or 'No details'

  getMarkdown: (key = '') ->
    return '' unless value = @[key.toLowerCase()]
    switch key
      when 'All', 'Text' then " #{value}"
      when 'Type', 'Project' then " __#{value}__"
      when 'Range', 'Line' then " _:#{value}_"
      when 'Regex' then " _'#{value}'_"
      when 'Path', 'File' then " [#{value}](#{value})"
      when 'Tags', 'Id' then " _#{value}_"

  getMarkdownArray: (keys) ->
    for key in keys or @getAllKeys()
      @getMarkdown(key)

  keyIsNumber: (key) ->
    key in ['Range', 'Line']

  contains: (string = '') ->
    for key in @getAllKeys()
      break unless item = @get(key)
      return true if item.toLowerCase().indexOf(string.toLowerCase()) isnt -1
    false

  handleScanMatch: (match) ->
    matchText = match.text or match.all or ''
    if matchText.length > match.all?.length
      match.all = matchText

    # Strip out the regex token from the found annotation
    # not all objects will have an exec match
    while (_matchText = match.regexp?.exec(matchText))
      # Find match type
      match.type = _matchText[1] unless match.type
      # Extract todo text
      matchText = _matchText.pop()

    # Extract google style guide todo id
    if matchText.indexOf('(') is 0
      if matches = matchText.match(/\((.*?)\):?(.*)/)
        matchText = matches.pop()
        match.id = matches.pop()

    matchText = @stripCommentEnd(matchText)

    # Extract todo tags
    match.tags = (while (tag = /\s*#(\w+)[,.]?$/.exec(matchText))
      break if tag.length isnt 2
      matchText = matchText.slice(0, -tag.shift().length)
      tag.shift()
    ).sort().join(', ')

    # Use text before todo if no content after
    if not matchText and match.all and pos = match.position?[0]?[1]
      matchText = match.all.substr(0, pos)
      matchText = @stripCommentStart(matchText)

    # Truncate long match strings
    if matchText.length >= maxLength
      matchText = "#{matchText.substr(0, maxLength - 3)}..."

    # Make sure range is serialized to produce correct rendered format
    match.position = [[0,0]] unless match.position and match.position.length > 0
    if match.position.serialize
      match.range = match.position.serialize().toString()
    else
      match.range = match.position.toString()

    # Extract paths and project
    relativePath = atom.project.relativizePath(match.loc)
    relativePath[0] ?= ''
    match.path = relativePath[1] or ''

    if (loc = path.basename(match.loc)) isnt 'undefined'
      match.file = loc
    else
      match.file = 'untitled'

    if (project = path.basename(relativePath[0])) isnt 'null'
      match.project = project
    else
      match.project = ''

    match.text = matchText or "No details"
    match.line = (parseInt(match.range.split(',')[0]) + 1).toString()
    match.regex = match.regex.replace('${TODOS}', match.type)
    match.id = match.id or ''

    _.extend(this, match)

  stripCommentStart: (text = '') ->
    startRegex = /(\/\*|<\?|<!--|<#|{-|\[\[|\/\/|#)\s*$/
    text.replace(startRegex, '').trim()

  stripCommentEnd: (text = '') ->
    endRegex = /(\*\/}?|\?>|-->|#>|-}|\]\])\s*$/
    text.replace(endRegex, '').trim()
