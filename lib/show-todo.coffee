{CompositeDisposable} = require 'atom'

ShowTodoView = require './todo-view'
TodoCollection = require './todo-collection'

module.exports =
  config:
    findTheseTodos:
      type: 'array'
      default: [
        'FIXME'
        'TODO'
        'CHANGED'
        'XXX'
        'IDEA'
        'HACK'
        'NOTE'
        'REVIEW'
      ]
      items:
        type: 'string'
    findUsingRegex:
      description: 'Single regex used to find all todos. ${TODOS} is replaced with the findTheseTodos array.'
      type: 'string'
      default: '/\\b(${TODOS}):?\\d*($|\\s.*$)/g'
    ignoreThesePaths:
      type: 'array'
      default: [
        '**/node_modules/'
        '**/vendor/'
        '**/bower_components/'
      ]
      items:
        type: 'string'
    showInTable:
      type: 'array'
      default: [
        'Text',
        'Type',
        'File'
      ]
    sortBy:
      type: 'string'
      default: 'Text'
      enum: ['All', 'Text', 'Type', 'Range', 'Line', 'Regex', 'File', 'Tags']
    sortAscending:
      type: 'boolean'
      default: true
    openListInDirection:
      type: 'string'
      default: 'right'
      enum: ['up', 'right', 'down', 'left', 'ontop']
    rememberViewSize:
      type: 'boolean'
      default: true
    saveOutputAs:
      type: 'string'
      default: 'List'
      enum: ['List', 'Table']

  URI:
    full: 'atom://todo-show/todos'
    open: 'atom://todo-show/open-todos'
    active: 'atom://todo-show/active-todos'

  activate: ->
    collection = new TodoCollection
    collection.setAvailableTableItems(@config.sortBy.enum)

    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'todo-show:find-in-project': => @show(@URI.full)
      'todo-show:find-in-open-files': => @show(@URI.open)

    # Register the todolist URI, which will then open our custom view
    @disposables.add atom.workspace.addOpener (uriToOpen) =>
      scope = switch uriToOpen
        when @URI.full then 'full'
        when @URI.open then 'open'
        when @URI.active then 'active'
      if scope
        collection.setSearchScope(scope)
        new ShowTodoView(collection, uriToOpen)

  deactivate: ->
    @disposables?.dispose()

  destroyPaneItem: ->
    pane = atom.workspace.paneForItem(@showTodoView)
    return false unless pane

    pane.destroyItem(@showTodoView)
    # Ignore core.destroyEmptyPanes and close empty pane
    pane.destroy() if pane.getItems().length is 0
    return true

  show: (uri) ->
    prevPane = atom.workspace.getActivePane()
    direction = atom.config.get('todo-show.openListInDirection')

    return if @destroyPaneItem()

    if direction is 'down'
      prevPane.splitDown() if prevPane.parent.orientation isnt 'vertical'
    else if direction is 'up'
      prevPane.splitUp() if prevPane.parent.orientation isnt 'vertical'

    atom.workspace.open(uri, split: direction).then (@showTodoView) =>
      prevPane.activate()
