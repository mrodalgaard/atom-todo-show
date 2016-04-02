{Emitter} = require 'atom'

TodoModel = require './todo-model'
TodosMarkdown = require './todo-markdown'
TodoRegex = require './todo-regex'

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

  # Scan project workspace for the TodoRegex object
  # returns a promise that the scan generates
  fetchRegexItem: (todoRegex) ->
    options =
      paths: @getIgnorePaths()
      onPathsSearched: (nPaths) =>
        @emitter.emit 'did-search-paths', nPaths if @isSearching()

    atom.workspace.scan todoRegex.regexp, options, (result, error) =>
      console.debug error.message if error
      return unless result

      for match in result.matches
        @addTodo new TodoModel(
          all: match.lineText
          text: match.matchText
          loc: result.filePath
          position: match.range
          regex: todoRegex.regex
          regexp: todoRegex.regexp
        )

  # Scan open files for the TodoRegex object
  fetchOpenRegexItem: (todoRegex, activeEditorOnly) ->
    editors = []
    if activeEditorOnly
      if editor = atom.workspace.getPanes()[0]?.getActiveEditor()
        editors = [editor]
    else
      editors = atom.workspace.getTextEditors()

    for editor in editors
      editor.scan todoRegex.regexp, (match, error) =>
        console.debug error.message if error
        return unless match

        range = [
          [match.computedRange.start.row, match.computedRange.start.column]
          [match.computedRange.end.row, match.computedRange.end.column]
        ]

        @addTodo new TodoModel(
          all: match.lineText
          text: match.matchText
          loc: editor.getPath()
          position: range
          regex: todoRegex.regex
          regexp: todoRegex.regexp
        )

    # No async operations, so just return a resolved promise
    Promise.resolve()

  search: ->
    @clear()
    @searching = true
    @emitter.emit 'did-start-search'

    todoRegex = new TodoRegex(
      atom.config.get('todo-show.findUsingRegex')
      atom.config.get('todo-show.findTheseTodos')
    )

    if todoRegex.error
      @emitter.emit 'did-fail-search', "Invalid todo search regex"
      return

    @searchPromise = switch @scope
      when 'open' then @fetchOpenRegexItem(todoRegex, false)
      when 'active' then @fetchOpenRegexItem(todoRegex, true)
      else @fetchRegexItem(todoRegex)

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
