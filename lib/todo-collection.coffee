{Emitter} = require 'atom'

TodoModel = require './todo-model'
TodosMarkdown = require './todo-markdown'

module.exports =
class TodoCollection
  constructor: ->
    @emitter = new Emitter
    @defaultKey = 'Text'
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
  onDidFilterTodos: (cb) -> @emitter.on 'did-filter-todos', cb
  onDidChangeSearchScope: (cb) -> @emitter.on 'did-change-scope', cb

  clear: ->
    @cancelSearch()
    @todos = []
    @emitter.emit 'did-clear-todos'

  addTodo: (todo) ->
    return if @alreadyExists(todo)
    @todos.push(todo)
    @emitter.emit 'did-add-todo', todo

  getTodos: -> @todos
  getTodosCount: -> @todos.length

  sortTodos: ({sortBy, sortAsc} = {}) ->
    sortBy ?= @defaultKey

    @todos = @todos.sort((a,b) ->
      aVal = a.get(sortBy)
      bVal = b.get(sortBy)

      # Fall back to text if values are the same
      [aVal, bVal] = [a.get(@defaultKey), b.get(@defaultKey)] if aVal is bVal

      if a.keyIsNumber(sortBy)
        comp = parseInt(aVal) - parseInt(bVal)
      else
        comp = aVal.localeCompare(bVal)
      if sortAsc then comp else -comp
    )

    # Apply filter if it exists
    return @filterTodos(@filter) if @filter
    @emitter.emit 'did-sort-todos', @todos

  filterTodos: (@filter) ->
    if filter
      result = @todos.filter (todo) ->
        todo.contains(filter)
    else
      result = @todos

    @emitter.emit 'did-filter-todos', result

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

  alreadyExists: (newTodo) ->
    properties = ['range', 'path']
    @todos.some (todo) ->
      properties.every (prop) ->
        true if todo[prop] is newTodo[prop]

  # Pass in string and returns a proper RegExp object
  makeRegexObj: (regexStr = '') ->
    # Extract the regex pattern (anything between the slashes)
    pattern = regexStr.match(/\/(.+)\//)?[1]
    # Extract the flags (after last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1]

    unless pattern
      @emitter.emit 'did-fail-search', "Invalid regex: #{regexStr or 'empty'}"
      return false
    new RegExp(pattern, flags)

  createRegex: (regexStr, todoList) ->
    unless Object.prototype.toString.call(todoList) is '[object Array]' and
    todoList.length > 0 and
    regexStr
      @emitter.emit 'did-fail-search', "Invalid todo search regex"
      return false
    @makeRegexObj(regexStr.replace('${TODOS}', todoList.join('|')))

  # Scan project workspace for the lookup that is passed
  # returns a promise that the scan generates
  fetchRegexItem: (regexp, regex = '') ->
    options =
      paths: @getIgnorePaths()
      onPathsSearched: (nPaths) =>
        @emitter.emit 'did-search-paths', nPaths if @isSearching()

    atom.workspace.scan regexp, options, (result, error) =>
      console.debug error.message if error
      return unless result

      for match in result.matches
        @addTodo new TodoModel(
          all: match.lineText
          text: match.matchText
          path: result.filePath
          position: match.range
          regex: regex
          regexp: regexp
        )

  # Scan open files for the lookup that is passed
  fetchOpenRegexItem: (regexp, regex = '', activeEditorOnly) ->
    editors = []
    if activeEditorOnly
      if editor = atom.workspace.getPanes()[0]?.getActiveEditor()
        editors = [editor]
    else
      editors = atom.workspace.getTextEditors()

    for editor in editors
      editor.scan regexp, (match, error) =>
        console.debug error.message if error
        return unless match

        range = [
          [match.computedRange.start.row, match.computedRange.start.column]
          [match.computedRange.end.row, match.computedRange.end.column]
        ]

        @addTodo new TodoModel(
          all: match.lineText
          text: match.matchText
          path: editor.getPath()
          position: range
          regex: regex
          regexp: regexp
        )

    # No async operations, so just return a resolved promise
    Promise.resolve()

  search: ->
    @clear()
    @searching = true
    @emitter.emit 'did-start-search'

    return unless regexp = @createRegex(
      regex = atom.config.get('todo-show.findUsingRegex')
      atom.config.get('todo-show.findTheseTodos')
    )

    @searchPromise = switch @scope
      when 'open' then @fetchOpenRegexItem(regexp, regex, false)
      when 'active' then @fetchOpenRegexItem(regexp, regex, true)
      else @fetchRegexItem(regexp, regex)

    @searchPromise.then () =>
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
    todosMarkdown = new TodosMarkdown
    todosMarkdown.markdown @getTodos()

  cancelSearch: ->
    @searchPromise?.cancel?()
