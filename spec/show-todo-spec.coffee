# Tests in this file are all about ensuring the command works properly and loads the proper panes...

ShowTodo = require '../lib/show-todo'

describe 'ShowTodo', ->
  [workspaceElement, activationPromise] = []

  # needed to activate packages that are using activationCommands
  executeCommand = (callback) ->
    atom.commands.dispatch(workspaceElement, 'todo-show:find-in-project')
    waitsForPromise -> activationPromise
    runs(callback)

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    #atom.workspaceView = workspaceElement.__spacePenView
    #jasmine.attachToDOM(workspaceElement)
    activationPromise = atom.packages.activatePackage('todo-show')

  describe 'when the show-todo:find-in-project event is triggered', ->
    it 'attaches and then detaches the pane view', ->
      expect(atom.packages.loadedPackages["todo-show"]).toBeDefined()
      
      expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()
      
      # open todo-show
      executeCommand ->
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()

        # close todo-show again
        executeCommand ->
          expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()
