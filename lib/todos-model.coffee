{Emitter} = require 'atom'

module.exports =
class TodosModel
  constructor: ->
    @emitter = new Emitter
    @maxLength = 120
    @scope = 'full'
    @todos = []

  onDidAddTodo: (cb) -> @emitter.on 'did-add-todo', cb
  onDidRemoveTodo: (cb) -> @emitter.on 'did-remove-todo', cb
  onDidClear: (cb) -> @emitter.on 'did-clear-todos', cb
  onDidStartSearch: (cb) -> @emitter.on 'did-start-search', cb
  onDidSearchPaths: (cb) -> @emitter.on 'did-search-paths', cb
  onDidFinishSearch: (cb) -> @emitter.on 'did-finish-search', cb
  onDidFailSearch: (cb) -> @emitter.on 'did-fail-search', cb
  onDidSortTodos: (cb) -> @emitter.on 'did-sort-todos', cb
  onDidChangeSearchScope: (cb) -> @emitter.on 'did-change-scope', cb

  clear: ->
    @cancelSearch()
    @todos = []
    @emitter.emit 'did-clear-todos'

  addTodo: (todo) ->
    # TODO: Check for duplicates and more
    @todos.push(todo)
    @emitter.emit 'did-add-todo', todo

  getTodos: -> @todos

  sortTodos: ({sortBy, sortAsc}) ->
    return unless sortBy

    @todos = @todos.sort((a,b) ->
      return -1 unless aItem = a[sortBy.toLowerCase()]
      return 1 unless bItem = b[sortBy.toLowerCase()]

      # Fall back to text if items are the same
      if aItem is bItem
        aItem = a.text
        bItem = b.text

      if sortAsc
        aItem.localeCompare(bItem)
      else
        bItem.localeCompare(aItem)
      )
    @emitter.emit 'did-sort-todos', @todos

  getAvailableTableItems: -> @availableItems
  setAvailableTableItems: (@availableItems) ->

  isSearching: -> @searching

  getSearchScope: -> @scope
  setSearchScope: (scope) ->
    @emitter.emit 'did-change-scope', @scope = scope

  toggleSearchScope: ->
    scope = switch @scope
      when 'full' then 'open'
      when 'open' then 'active'
      else 'full'
    @setSearchScope(scope)
    scope

  # Get regexes to look for from settings
  buildRegexLookups: (regexes) ->
    if regexes.length % 2
      @emitter.emit 'did-fail-search', "Invalid number of regexes: #{regexes.length}"
      return []

    for regex, i in regexes by 2
      'title': regex
      'regex': regexes[i+1]

  # Pass in string and returns a proper RegExp object
  makeRegexObj: (regexStr = "") ->
    # Extract the regex pattern (anything between the slashes)
    pattern = regexStr.match(/\/(.+)\//)?[1]
    # Extract the flags (after last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1]

    unless pattern
      @emitter.emit 'did-fail-search', "Invalid regex: #{regexStr or 'empty'}"
      return false
    new RegExp(pattern, flags)

  handleScanMatch: (match) ->
    matchText = match.text || match.all

    # Strip out the regex token from the found annotation
    # not all objects will have an exec match
    while (_matchText = match.regexp?.exec(matchText))
      matchText = _matchText.pop()

    # Strip common block comment endings and whitespaces
    matchText = matchText.replace(/(\*\/|\?>|-->|#>|-}|\]\])\s*$/, '').trim()

    # Truncate long match strings
    if matchText.length >= @maxLength
      matchText = "#{matchText.substring(0, @maxLength - 3)}..."

    # Make sure range is serialized to produce correct rendered format
    # See https://github.com/mrodalgaard/atom-todo-show/issues/27
    match.position = [[0,0]] unless match.position and match.position.length > 0
    if match.position.serialize
      match.range = match.position.serialize().toString()
    else
      match.range = match.position.toString()

    match.text = matchText || "No details"
    match.file = atom.project.relativize(match.path)
    match.line = parseInt(match.range.split(',')[0]) + 1
    return match

  # Scan project workspace for the lookup that is passed
  # returns a promise that the scan generates
  fetchRegexItem: (regexLookup) ->
    regex = @makeRegexObj(regexLookup.regex)
    return false unless regex

    options = {paths: @getIgnorePaths()}

    # Only track progress on first scan
    if !@firstRegex
      @firstRegex = true
      options.onPathsSearched = (nPaths) =>
        @emitter.emit 'did-search-paths', nPaths if @searching

    atom.workspace.scan regex, options, (result, error) =>
      console.debug error.message if error
      return unless result

      for match in result.matches
        @addTodo @handleScanMatch(
          all: match.lineText
          text: match.matchText
          path: result.filePath
          position: match.range
          type: regexLookup.title
          regex: regexLookup.regex
          regexp: regex
        )

  # Scan open files for the lookup that is passed
  fetchOpenRegexItem: (regexLookup, activeEditorOnly) ->
    regex = @makeRegexObj(regexLookup.regex)
    return false unless regex

    editors = []
    if activeEditorOnly
      if editor = atom.workspace.getPanes()[0]?.getActiveEditor()
        editors = [editor]
    else
      editors = atom.workspace.getTextEditors()

    for editor in editors
      editor.scan regex, (match, error) =>
        console.debug error.message if error
        return unless match

        range = [
          [match.computedRange.start.row, match.computedRange.start.column]
          [match.computedRange.end.row, match.computedRange.end.column]
        ]

        @addTodo @handleScanMatch(
          all: match.lineText
          text: match.matchText
          path: editor.getPath()
          position: range
          type: regexLookup.title
          regex: regexLookup.regex
          regexp: regex
        )

    # No async operations, so just return a resolved promise
    Promise.resolve()

  search: ->
    @clear()
    @searching = true
    @emitter.emit 'did-start-search'

    return unless findTheseRegexes = atom.config.get('todo-show.findTheseRegexes')
      # return @emitter.emit 'did-fail-search', "No todo regexes found"
    regexes = @buildRegexLookups(findTheseRegexes)

    # Scan for each regex and get promises
    for regexObj in regexes
      promise = switch @scope
        when 'open' then @fetchOpenRegexItem(regexObj, false)
        when 'active' then @fetchOpenRegexItem(regexObj, true)
        else @fetchRegexItem(regexObj)
      @searchPromises.push(promise)

    Promise.all(@searchPromises).then () =>
      @searching = false
      @emitter.emit 'did-finish-search'
    .catch (err) =>
      @searching = false
      @emitter.emit 'did-fail-search', err

  getIgnorePaths: ->
    ignores = atom.config.get('todo-show.ignoreThesePaths')
    return ['*'] unless ignores?
    if Object.prototype.toString.call(ignores) isnt '[object Array]'
      @emitter.emit 'did-fail-search', "ignoreThesePaths must be an array"
      return ['*']
    "!#{ignore}" for ignore in ignores

  getMarkdown: ->
    (for todo in @getTodos()
      out = '-'
      for key in atom.config.get('todo-show.showInTable')
        if item = todo[key.toLowerCase()]
          out += switch key
            when 'All' then " #{item}"
            when 'Text' then " #{item}"
            when 'Type' then " __#{item}__"
            when 'Range' then " _:#{item}_"
            when 'Line' then " _:#{item}_"
            when 'Regex' then " _'#{item}'_"
            when 'File' then " `#{item}`"
      out = "- No details" if out is '-'
      "#{out}\n"
    ).join('')

  cancelSearch: ->
    @searchPromises ?= []
    for promise in @searchPromises
      promise.cancel?() if promise
