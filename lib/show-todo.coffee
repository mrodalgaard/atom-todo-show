{CompositeDisposable} = require 'atom'

ShowTodoView = require './todo-view'
TodoCollection = require './todo-collection'
TodoIndicatorView = null

module.exports =
  config:
    findTheseTodos:
      description: 'An array of todo types used by the search regex.'
      type: 'array'
      default: [
        'TODO'
        'FIXME'
        'CHANGED'
        'XXX'
        'IDEA'
        'HACK'
        'NOTE'
        'REVIEW'
        'NB'
        'BUG'
        'QUESTION'
        'COMBAK'
        'TEMP'
      ]
      items:
        type: 'string'
    findUsingRegex:
      description: 'Regex string used to find all your todos. `${TODOS}` is replaced with `FindTheseTodos` from above.'
      type: 'string'
      default: '/\\b(${TODOS})[:;.,]?\\d*($|\\s.*$|\\(.*$)/g'
    ignoreThesePaths:
      description: 'Similar to `.gitignore` (remember to use `/` on Mac/Linux and `\\` on Windows for subdirectories).'
      type: 'array'
      default: [
        'node_modules'
        'vendor'
        'bower_components'
      ]
      items:
        type: 'string'
    showInTable:
      description: 'An array of properties to show for each todo in table.'
      type: 'array'
      default: ['Text', 'Type', 'Path']
    sortBy:
      type: 'string'
      default: 'Text'
      enum: ['All', 'Text', 'Type', 'Range', 'Line', 'Regex', 'Path', 'File', 'Tags', 'Id', 'Project']
    sortAscending:
      type: 'boolean'
      default: true
    saveOutputAs:
      type: 'string'
      default: 'List'
      enum: ['List', 'Table']
    statusBarIndicator:
      type: 'boolean'
      default: false

  URI: 'atom://todo-show'

  activate: ->
    @collection = new TodoCollection
    @collection.setAvailableTableItems(@config.sortBy.enum)

    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'todo-show:toggle': => @show()
      'todo-show:find-in-workspace': => @show('workspace')
      'todo-show:find-in-project': => @show('project')
      'todo-show:find-in-open-files': => @show('open')
      'todo-show:find-in-active-file': => @show('active')

    @disposables.add atom.workspace.addOpener (uri) =>
      new ShowTodoView(@collection, uri) if uri is @URI

  deactivate: ->
    @destroyTodoIndicator()
    @showTodoView?.destroy()
    @disposables?.dispose()

  show: (scope) ->
    if scope
      prevScope = @collection.scope
      if prevScope isnt scope
        @collection.setSearchScope scope
        return if @showTodoView?.isVisible()

    prevPane = atom.workspace.getActivePane()
    atom.workspace.toggle(@URI).then (@showTodoView) =>
      prevPane.activate()

  consumeStatusBar: (statusBar) ->
    atom.config.observe 'todo-show.statusBarIndicator', (newValue) =>
      if newValue
        TodoIndicatorView ?= require './todo-indicator-view'
        @todoIndicatorView ?= new TodoIndicatorView(@collection)
        @statusBarTile = statusBar.addLeftTile(item: @todoIndicatorView, priority: 200)
      else
        @destroyTodoIndicator()

  destroyTodoIndicator: ->
    @todoIndicatorView?.destroy()
    @todoIndicatorView = null
    @statusBarTile?.destroy()
    @statusBarTile = null
