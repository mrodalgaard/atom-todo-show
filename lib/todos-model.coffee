{Emitter} = require 'atom'

module.exports =
class TodosModel
  URI: 'atom://todo-show/todos'
  URIopen: 'atom://todo-show/open-todos'
  URIactive: 'atom://todo-show/active-todos'

  constructor: ->
    @emitter = new Emitter
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
    return unless key = @getKeyForItem(sortBy)

    @todos = @todos.sort((a,b) ->
      if sortAsc
        a[key].localeCompare(b[key])
      else
        b[key].localeCompare(a[key])
      )
    @emitter.emit 'did-sort-todos', @todos

  # TODO: Use keys as identifiers everywhere in the package instead of title
  # + better / consistent naming
  # Todo object structure:
  #   lineText
  #   matchText
  #   path
  #   range
  #   rangeString
  #   regex
  #   relativePath
  #   title
  getKeyForItem: (item) ->
    switch item
      when 'Message' then 'matchText'
      when 'Text' then 'lineText'
      when 'Type' then 'title'
      when 'Range' then 'rangeString'
      when 'Line' then 'line'
      when 'Regex' then 'regex'
      when 'File' then 'relativePath'

  getAvailableTableItems: -> @availableItems
  setAvailableTableItems: (@availableItems) ->

  isSearching: -> @searching

  getSearchScope: -> @scope
  setSearchScope: (scope) ->
    @emitter.emit 'did-change-scope', @scope = scope

  setSearchScopeFromUri: (uri) ->
    scope = switch uri
      when @URI then 'full'
      when @URIopen then 'open'
      when @URIactive then 'active'
    if scope then @scope = scope else false

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
      @showError "Invalid number of regexes: #{regexes.length}"
      return []

    for regex, i in regexes by 2
      'title': regex
      'regex': regexes[i+1]

  # Pass in string and returns a proper RegExp object
  makeRegexObj: (regexStr = '') ->
    # Extract the regex pattern (anything between the slashes)
    pattern = regexStr.match(/\/(.+)\//)?[1]
    # Extract the flags (after last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1]

    if pattern
      new RegExp(pattern, flags)
    else
      @showError "Invalid regex: #{regexStr or 'empty'}"
      false

  handleScanMatch: (match, regex) ->
    matchText = match.matchText

    # Strip out the regex token from the found annotation
    # not all objects will have an exec match
    while (_match = regex?.exec(matchText))
      matchText = _match.pop()

    # Strip common block comment endings and whitespaces
    matchText = matchText.replace(/(\*\/|\?>|-->|#>|-}|\]\])\s*$/, '').trim()

    # Truncate long match strings
    if matchText.length >= @maxLength
      matchText = "#{matchText.substring(0, @maxLength - 3)}..."

    match.matchText = matchText || 'No details'

    # Make sure range is serialized to produce correct rendered format
    # See https://github.com/jamischarles/atom-todo-show/issues/27
    if match.range.serialize
      match.rangeString = match.range.serialize().toString()
    else
      match.rangeString = match.range.toString()

    match.relativePath = atom.project.relativize(match.path)
    match.line = match.range[0][0] + 1
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
        match.title = regexLookup.title
        match.regex = regexLookup.regex
        match.path = result.filePath
        @addTodo @handleScanMatch(match, regex)

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
      editor.scan regex, (result, error) =>
        console.debug error.message if error
        return unless result

        match =
          title: regexLookup.title
          regex: regexLookup.regex
          path: editor.getPath()
          matchText: result.matchText
          lineText: result.matchText
          range: [
            [
              result.computedRange.start.row
              result.computedRange.start.column
            ]
            [
              result.computedRange.end.row
              result.computedRange.end.column
            ]
          ]
        @addTodo @handleScanMatch(match, regex)

    # No async operations, so just return a resolved promise
    Promise.resolve()

  search: ->
    @clear()
    @searching = true
    @emitter.emit 'did-start-search'

    regexes = @buildRegexLookups(atom.config.get('todo-show.findTheseRegexes'))

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
      @showError('ignoreThesePaths must be an array')
      return ['*']
    "!#{ignore}" for ignore in ignores

  # groupMatches: (matches, cb) ->
  #   regexes = atom.config.get('todo-show.findTheseRegexes')
  #   groupBy = atom.config.get('todo-show.groupMatchesBy')
  #
  #   switch groupBy
  #     when 'file'
  #       iteratee = 'relativePath'
  #       sortedMatches = _.sortBy(matches, iteratee)
  #     when 'none'
  #       sortedMatches = _.sortBy(matches, 'matchText')
  #       return cb(sortedMatches, groupBy)
  #     else
  #       iteratee = 'title'
  #       sortedMatches = _.sortBy(matches, (match) ->
  #         regexes.indexOf(match[iteratee])
  #       )
  #
  #   for own key, group of _.groupBy(sortedMatches, iteratee)
  #     cb(group, groupBy)

  # getMarkdown: ->
  #   markdown = []
  #   @groupMatches(matches, (group, groupBy) ->
  #     switch groupBy
  #       when 'file'
  #         out = "\n## #{group[0].relativePath || 'Unknown File'}\n\n"
  #         for match in group
  #           out += "- #{match.matchText || 'empty'}"
  #           out += " `#{match.title}`" if match.title
  #           out += "\n"
  #
  #       when 'none'
  #         out = "\n## All Matches\n\n"
  #         for match in group
  #           out += "- #{match.matchText || 'empty'}"
  #           out += " _(#{match.title})_" if match.title
  #           out += " `#{match.relativePath}`" if match.relativePath
  #           out += " `:#{match.range[0][0] + 1}`" if match.range and match.range[0]
  #           out += "\n"
  #
  #       else
  #         out = "\n## #{group[0].title || 'No Title'}\n\n"
  #         for match in group
  #           out += "- #{match.matchText || 'empty'}"
  #           out += " `#{match.relativePath}`" if match.relativePath
  #           out += " `:#{match.range[0][0] + 1}`" if match.range and match.range[0]
  #           out += "\n"
  #     markdown.push out
  #   )
  #   markdown.join('')

  getMarkdown: ->
    showInTableKeys = for item in atom.config.get('todo-show.showInTable')
      @getKeyForItem(item)

    (for todo in @getTodos()
      out = '- '
      for key in showInTableKeys
        out += switch key
          when 'matchText' then " #{todo[key]}"
          when 'lineText' then " #{todo[key]}"
          when 'title' then " `#{todo[key]}`"
          when 'rangeString' then " _:#{todo[key]}_"
          when 'line' then " _:#{todo[key]}_"
          when 'regex' then " _#{todo[key]}_"
          when 'relativePath' then " `#{todo[key]}`"
      "#{out}\n"
    ).join('')

  cancelSearch: ->
    @searchPromises ?= []
    for promise in @searchPromises
      promise.cancel?() if promise
