# Deps
querystring = require 'querystring'
url = require 'url'
fs = require 'fs-plus'

# Local files
ShowTodoView = require './show-todo-view'


module.exports =
  showTodoView: null

  activate: (state) ->
    atom.workspaceView.command 'show-todo:toggle', =>
      @show()
    # @show()
    # @showTodoView = new ShowTodoView(state.showTodoViewState)

    # register the todolist URI. Which will then open our custom view
    atom.workspace.registerOpener (uriToOpen) ->
      console.log('REGISTER OPENER CALLED222', uriToOpen)
      {protocol, pathname} = url.parse(uriToOpen)
      pathname = querystring.unescape(pathname) if pathname
      return unless protocol is 'todolist-preview:' and fs.isFileSync(pathname)
      console.log('REGISTER OPENER CALLED444', uriToOpen)
      new ShowTodoView(pathname)


  findTodos: ->
    atom.project.scan /todo/, (e) ->
      console.log(e)

  deactivate: ->
    @showTodoView.destroy()

  serialize: ->
    showTodoViewState: @showTodoView.serialize()

  show: (todoContent )->
    console.log 'show called'
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    # unless editor.getGrammar().scopeName is "source.gfm"
    #   console.warn("Cannot render markdown for '#{editor.getUri() ? 'untitled'}'")
    #   return
    #
    # unless fs.isFileSync(editor.getPath())
    #   console.warn("Cannot render markdown for '#{editor.getPath() ? 'untitled'}'")
    #   return

    previousActivePane = atom.workspace.getActivePane()
    uri = "todolist-preview://#{editor.getPath()}"
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (showTodoView) ->
      # TODO: we could require it in, and use a similar pattern as the other one...
      console.log(arguments)
      arguments[0].innerHTML = "WE HAVE LIFTOFF"
      if showTodoView instanceof ShowTodoView
        showTodoView.renderTodos() #do the initial render
      previousActivePane.activate()
