{CompositeDisposable} = require 'atom'
url = require 'url'

ShowTodoView = require './show-todo-view'

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
        '*/node_modules/'
        '*/vendor/'
        '*/bower_components/'
      ]
      items:
        type: 'string'
    # Split direction to open list
    openListInDirection:
      type: 'string'
      default: 'right'
      enum: ['up', 'right', 'down', 'left', 'ontop']
    # Change list grouping / sorting
    groupMatchesBy:
      type: 'string'
      default: 'regex'
      enum: ['regex', 'file', 'none']
    # Persist pane width / height
    rememberViewSize:
      type: 'boolean'
      default: true

  activate: ->
    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'todo-show:find-in-project': => @show('todolist-preview:///TODOs')
      'todo-show:find-in-open-files': => @show('todolist-preview:///Open-TODOs')

    # Register the todolist URI, which will then open our custom view
    @disposables.add atom.workspace.addOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'todolist-preview:'
      new ShowTodoView(filePath: pathname).getTodos()

  deactivate: ->
    @paneDisposables?.dispose()
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

    atom.workspace.open(uri, split: direction).done (@showTodoView) =>
      prevPane.activate()
