{CompositeDisposable} = require 'atom'

ShowTodoView = require './show-todo-view'
TodosModel = require './todos-model'

module.exports =
  config:
    # Title, regex, title, regex...
    findTheseRegexes:
      type: 'array'
      # Based on https://github.com/atom/language-todo
      default: [
        'FIXMEs'
        '/\\bFIXME:?\\d*($|\\s.*$)/g'
        'TODOs'
        '/\\bTODO:?\\d*($|\\s.*$)/g'
        'CHANGEDs'
        '/\\bCHANGED:?\\d*($|\\s.*$)/g'
        'XXXs'
        '/\\bXXX:?\\d*($|\\s.*$)/g'
        'IDEAs'
        '/\\bIDEA:?\\d*($|\\s.*$)/g'
        'HACKs'
        '/\\bHACK:?\\d*($|\\s.*$)/g'
        'NOTEs'
        '/\\bNOTE:?\\d*($|\\s.*$)/g'
        'REVIEWs'
        '/\\bREVIEW:?\\d*($|\\s.*$)/g'
      ]
      items:
        type: 'string'
    # Ignore filter using node-ignore
    ignoreThesePaths:
      type: 'array'
      default: [
        '**/node_modules/'
        '**/vendor/'
        '**/bower_components/'
      ]
      items:
        type: 'string'
    # Show these todo properties in todo table
    showInTable:
      type: 'array'
      default: [
        'Message',
        'Type',
        'File'
      ]
    # Sort by todo property
    sortBy:
      type: 'string'
      default: 'Message'
      enum: ['Message', 'Text', 'Type', 'Range', 'Line', 'Regex', 'File']
    # Sort ascending or descending
    sortAscending:
      type: 'boolean'
      default: true
    # Split direction to open list
    openListInDirection:
      type: 'string'
      default: 'right'
      enum: ['up', 'right', 'down', 'left', 'ontop']
    # Persist pane width / height
    rememberViewSize:
      type: 'boolean'
      default: true

  URI:
    full: 'atom://todo-show/todos'
    open: 'atom://todo-show/open-todos'
    active: 'atom://todo-show/active-todos'

  activate: ->
    model = new TodosModel
    model.setAvailableTableItems(@config.sortBy.enum)

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
        model.setSearchScope(scope)
        new ShowTodoView(model, uriToOpen)

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
