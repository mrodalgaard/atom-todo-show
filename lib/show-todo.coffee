# All this file really does is handle the following
# 1) Defines Regex defaults
# 2) Instantiates the commands, the panes, and then calls showTodoView.renderTodos()

url = require 'url'

ShowTodoView = require './show-todo-view'

module.exports =
  config:
    # title, regex, title, regex...
    findTheseRegexes:
      type: 'array'
      default: [
        'FIXMEs'
        '/FIXME:?(.+$)/g'
        'TODOs'
        '/TODO:?(.+$)/g'
        'CHANGEDs'
        '/CHANGED:?(.+$)/g'
        'XXXs'
        '/XXX:?(.+$)/g'
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
      @show()

    # register the todolist URI, which will then open our custom view
    atom.workspace.addOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)
      pathname = decodeURI(pathname) if pathname
      return unless protocol is 'todolist-preview:'
      new ShowTodoView(filePath: pathname)

  show: ->
    uri = "todolist-preview://TODOs"
    prevPane = atom.workspace.getActivePane()
    pane = atom.workspace.paneForItem(@showTodoView)
    direction = atom.config.get('todo-show.openListInDirection')

    if pane
      pane.destroyItem(@showTodoView)
      # ignore core.destroyEmptyPanes and close empty pane
      pane.destroy() if pane.getItems().length is 0
      return

    if direction == 'down'
      prevPane.splitDown() if prevPane.parent.orientation != 'vertical'
    else if direction == 'up'
      prevPane.splitUp() if prevPane.parent.orientation != 'vertical'

    atom.workspace.open(uri, split: direction).done (@showTodoView) =>
      @showTodoView.renderTodos() if @showTodoView instanceof ShowTodoView
      prevPane.activate()
