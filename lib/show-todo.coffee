# All this file really does is handle the following
# 1) Defines Regex defaults
# 2) Instantiates the commands, the panes, and then calls showTodoView.renderTodos()

querystring = require 'querystring'
url = require 'url'
fs = require 'fs-plus'

ShowTodoView = require './show-todo-view'


module.exports =
  showTodoView: null
  
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

  activate: (state) ->
    atom.commands.add 'atom-workspace', 'todo-show:find-in-project': =>
      @show()
    # @showTodoView = new ShowTodoView(state.showTodoViewState)

    # register the todolist URI. Which will then open our custom view
    atom.workspace.addOpener (uriToOpen) ->
      # console.log('REGISTER OPENER CALLED222', uriToOpen)
      {protocol, pathname} = url.parse(uriToOpen)
      pathname = querystring.unescape(pathname) if pathname
      return unless protocol is 'todolist-preview:'
      # console.log('REGISTER OPENER CALLED444', uriToOpen)
      new ShowTodoView(pathname)

  deactivate: ->
    @showTodoView?.destroy()

  serialize: ->
    showTodoViewState: @showTodoView?.serialize()

  show: ->
    previousActivePane = atom.workspace.getActivePane()
    uri = "todolist-preview://TODOs"
    pane = atom.workspace.paneForItem(@showTodoView)
    
    if pane
      pane.destroyItem(@showTodoView)
      # ignore core.destroyEmptyPanes and close empty pane
      pane.destroy() if pane.getItems().length is 0
    else
      atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (textEditorView) =>
        @showTodoView = textEditorView;

        # TODO: we could require it in, and use a similar pattern as the other one...
        
        arguments[0].innerHTML = "WE HAVE LIFTOFF"
        if @showTodoView instanceof ShowTodoView
          @showTodoView.renderTodos() #do the initial render
        previousActivePane.activate()
