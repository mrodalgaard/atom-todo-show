# This file handles configuration defaults, opening of pane and commands

url = require 'url'

ShowTodoView = require './show-todo-view'

module.exports =
  config:
    # title, regex, title, regex...
    findTheseRegexes:
      type: 'array'
      default: [ # based on atom/language-todo
        'FIXMEs'
        '/\\b@?FIXME:?\\s(.+$)/g'
        'TODOs'
        '/\\b@?TODO:?\\s(.+$)/g'
        'CHANGEDs'
        '/\\b@?CHANGED:?\\s(.+$)/g'
        'XXXs'
        '/\\b@?XXX:?\\s(.+$)/g'
        'IDEAs'
        '/\\b@?IDEA:?\\s(.+$)/g'
        'HACKs'
        '/\\b@?HACK:?\\s(.+$)/g'
        'NOTEs'
        '/\\b@?NOTE:?\\s(.+$)/g'
        'REVIEWs'
        '/\\b@?REVIEW:?\\s(.+$)/g'
      ]
      items:
        type: 'string'
    # ignore filter using node-ignore
    ignoreThesePaths:
      type: 'array'
      default: [
        '*/node_modules/'
        '*/vendor/'
        '*/bower_components/'
      ]
      items:
        type: 'string'
    # split direction to open list
    openListInDirection:
      type: 'string'
      default: 'right'
      enum: ['up', 'right', 'down', 'left', 'ontop']

  activate: ->
    atom.commands.add 'atom-workspace', 'todo-show:find-in-project': =>
      @show('todolist-preview:///TODOs')

    atom.commands.add 'atom-workspace', 'todo-show:find-in-open-files': =>
      @show('todolist-preview:///Open-TODOs')

    # Register the todolist URI, which will then open our custom view
    atom.workspace.addOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'todolist-preview:'
      new ShowTodoView(filePath: pathname).renderTodos()

  show: (uri) ->
    prevPane = atom.workspace.getActivePane()
    pane = atom.workspace.paneForItem(@showTodoView)
    direction = atom.config.get('todo-show.openListInDirection')

    if pane
      pane.destroyItem(@showTodoView)
      # Ignore core.destroyEmptyPanes and close empty pane
      pane.destroy() if pane.getItems().length is 0
      return

    if direction is 'down'
      prevPane.splitDown() if prevPane.parent.orientation isnt 'vertical'
    else if direction is 'up'
      prevPane.splitUp() if prevPane.parent.orientation isnt 'vertical'

    atom.workspace.open(uri, split: direction).done (@showTodoView) =>
      prevPane.activate()
