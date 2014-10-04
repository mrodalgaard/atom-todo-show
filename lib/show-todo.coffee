# All this file really does is handle the following
# 1) Defines Regex defaults
# 2) Instantiates the commands, the panes, and then calls showTodoView.renderTodos()

# Deps
querystring = require 'querystring'
url = require 'url'
fs = require 'fs-plus'

# Local files
ShowTodoView = require './show-todo-view'


module.exports =
  showTodoView: null
  configDefaults:
    findTheseRegexes: [
      'FIXMEs'
      '/FIXME:?(.+$)/g'
      'TODOs' #title
      '/TODO:?(.+$)/g'
      'CHANGEDs'
      '/CHANGED:?(.+$)/g'
      'XXXs'
      '/XXX:?(.+$)/g'
    ],
    ignoreThesePaths: [
      '/node_modules/'
      '/vendor/'
    ]

  activate: (state) ->
    atom.workspaceView.command 'todo-show:find-in-project', => #this one is tied to the one in package.json
      @show()
    # @show()
    # @showTodoView = new ShowTodoView(state.showTodoViewState)

    # register the todolist URI. Which will then open our custom view
    atom.workspace.registerOpener (uriToOpen) ->
      # console.log('REGISTER OPENER CALLED222', uriToOpen)
      {protocol, pathname} = url.parse(uriToOpen)
      pathname = querystring.unescape(pathname) if pathname
      return unless protocol is 'todolist-preview:'
      # console.log('REGISTER OPENER CALLED444', uriToOpen)
      new ShowTodoView(pathname)


  # findTodos: ->
  #   atom.project.scan /todo/, (e) ->
  #     console.log(e)

  deactivate: ->
    @showTodoView.destroy()
    #CHANGED
    #NOTE:
  serialize: ->
    showTodoViewState: @showTodoView.serialize()

  show: (todoContent )->
    # editor = atom.workspace.getActiveEditor()
    # return unless editor?

    # unless editor.getGrammar().scopeName is "source.gfm"
    #   console.warn("Cannot render markdown for '#{editor.getUri() ? 'untitled'}'")
    #   return
    #
    # unless fs.isFileSync(editor.getPath())
    #   console.warn("Cannot render markdown for '#{editor.getPath() ? 'untitled'}'")
    #   return

    previousActivePane = atom.workspace.getActivePane()
    uri = "todolist-preview://TODOs"
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (showTodoView) ->
      # TODO: we could require it in, and use a similar pattern as the other one...
      # console.log(arguments)
      arguments[0].innerHTML = "WE HAVE LIFTOFF"
      if showTodoView instanceof ShowTodoView
        showTodoView.renderTodos() #do the initial render
      previousActivePane.activate()
