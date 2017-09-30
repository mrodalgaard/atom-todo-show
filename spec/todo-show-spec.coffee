path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'

nTodos = 28

describe 'ShowTodo opening panes and executing commands', ->
  [workspaceElement, activationPromise, showTodoModule, showTodoPane] = []

  # Needed to activate packages that are using activationCommands
  # and wait for loading to stop
  executeCommand = (callback) ->
    wasVisible = showTodoModule?.showTodoView?.isVisible()
    atom.commands.dispatch(workspaceElement, 'todo-show:find-in-workspace')
    waitsForPromise -> activationPromise
    runs ->
      waitsFor ->
        return !showTodoModule.showTodoView?.isVisible() if wasVisible
        !showTodoModule.showTodoView.isSearching() and showTodoModule.showTodoView.isVisible()
      runs ->
        showTodoPane = atom.workspace.paneForItem(showTodoModule.showTodoView)
        callback()

  beforeEach ->
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]
    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)
    activationPromise = atom.packages.activatePackage('todo-show').then (opts) ->
      showTodoModule = opts.mainModule

  describe 'when the todo-show:find-in-workspace event is triggered', ->
    it 'attaches and toggles the pane view in dock', ->
      dock = atom.workspace.getRightDock()
      expect(atom.packages.loadedPackages['todo-show']).toBeDefined()
      expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()
      expect(dock.isVisible()).toBe false

      # open todo-show
      executeCommand ->
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(dock.isVisible()).toBe true
        expect(dock.getActivePaneItem()).toBe showTodoModule?.showTodoView

        # close todo-show again
        executeCommand ->
          expect(dock.isVisible()).toBe false

    it 'activates', ->
      expect(atom.packages.loadedPackages['todo-show']).toBeDefined()
      expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

    it 'does not search when not visible', ->
      dock = atom.workspace.getRightDock()
      executeCommand ->
        waitsFor -> showTodoModule.collection.getTodosCount() > 0
        runs ->
          expect(dock.isVisible()).toBe true
          expect(showTodoModule.collection.getTodosCount()).toBe nTodos

          editor = undefined
          atom.workspace.open('sample.js')
          waitsFor -> editor = atom.workspace.getActiveTextEditor()
          runs ->
            prevText = editor.getText()
            editor.insertText 'TODO: This is an inserted todo'
            waitsForPromise -> editor.save()
            runs ->
              expect(showTodoModule.showTodoView.isSearching()).toBe true

              waitsFor -> showTodoModule.collection.getTodosCount() > 0
              runs ->
                expect(showTodoModule.collection.getTodosCount()).toBe(nTodos + 1)

                executeCommand ->
                  editor.setText prevText
                  waitsForPromise -> editor.save()
                  runs ->
                    expect(showTodoModule.showTodoView).not.toBeDefined()
                    expect(showTodoModule.collection.getTodosCount()).toBe(nTodos + 1)

                    dock.show()
                    waitsForPromise -> editor.save()
                    runs ->
                      waitsFor -> showTodoModule.collection.getTodosCount() > 0
                      runs ->
                        expect(showTodoModule.collection.getTodosCount()).toBe nTodos

  describe 'when todo item is clicked', ->
    it 'opens the file', ->
      executeCommand ->
        element = showTodoModule.showTodoView.find('td').last()
        item = atom.workspace.getActivePaneItem()
        expect(item).not.toBeDefined()
        element.click()

        waitsFor -> item = atom.workspace.getActivePaneItem()
        runs -> expect(item.getTitle()).toBe 'sample.js'

    it 'opens file other project', ->
      atom.project.addPath path.join(__dirname, 'fixtures/sample2')

      executeCommand ->
        element = showTodoModule.showTodoView.find('td')[3]
        item = atom.workspace.getActivePaneItem()
        expect(item).not.toBeDefined()
        element.click()

        waitsFor -> item = atom.workspace.getActivePaneItem()
        runs -> expect(item.getTitle()).toBe 'sample.txt'

  describe 'when save-as button is clicked', ->
    it 'saves the list in markdown and opens it', ->
      outputPath = temp.path(suffix: '.md')
      expectedFilePath = atom.project.getDirectories()[0].resolve('../saved-output.md')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()
      atom.config.set 'todo-show.sortBy', 'Type'

      expect(fs.isFileSync(outputPath)).toBe false

      executeCommand ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        showTodoModule.showTodoView.saveAs()

      waitsFor ->
        fs.existsSync(outputPath) && atom.workspace.getActiveTextEditor()?.getPath() is outputPath

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        # Not working in Travis CI
        # expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput

    it 'saves another list sorted differently in markdown', ->
      outputPath = temp.path(suffix: '.md')
      atom.config.set 'todo-show.findTheseTodos', ['TODO']
      atom.config.set 'todo-show.showInTable', ['Text', 'Type', 'File', 'Line']
      atom.config.set 'todo-show.sortBy', 'File'
      expect(fs.isFileSync(outputPath)).toBe false

      executeCommand ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        showTodoModule.showTodoView.saveAs()

      waitsFor ->
        fs.existsSync(outputPath) && atom.workspace.getActiveTextEditor()?.getPath() is outputPath

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        expect(atom.workspace.getActiveTextEditor().getText()).toBe """
          - Comment in C __TODO__ [sample.c](sample.c) _:5_
          - This is the first todo __TODO__ [sample.js](sample.js) _:3_
          - This is the second todo __TODO__ [sample.js](sample.js) _:20_\n
        """

  describe 'when core:refresh is triggered', ->
    it 'refreshes the list', ->
      executeCommand ->
        atom.commands.dispatch workspaceElement.querySelector('.show-todo-preview'), 'core:refresh'

        expect(showTodoModule.showTodoView.isSearching()).toBe true
        expect(showTodoModule.showTodoView.find('.markdown-spinner')).toBeVisible()

        waitsFor -> !showTodoModule.showTodoView.isSearching()
        runs ->
          expect(showTodoModule.showTodoView.find('.markdown-spinner')).not.toBeVisible()
          expect(showTodoModule.showTodoView.isSearching()).toBe false

  describe 'when the todo-show:find-in-open-files event is triggered', ->
    beforeEach ->
      atom.commands.dispatch(workspaceElement, 'todo-show:find-in-open-files')
      waitsForPromise -> activationPromise
      runs ->
        waitsFor ->
          !showTodoModule.showTodoView.isSearching() and showTodoModule.showTodoView.isVisible()

    it 'does not show any results with no open files', ->
      element = showTodoModule.showTodoView.find('p').last()

      expect(showTodoModule.showTodoView.getTodos()).toHaveLength 0
      expect(element.text()).toContain 'No results...'
      expect(element.isVisible()).toBe true

    it 'only shows todos from open files', ->
      waitsForPromise ->
        atom.workspace.open 'sample.c'

      waitsFor -> !showTodoModule.showTodoView.isSearching()
      runs ->
        todos = showTodoModule.showTodoView.getTodos()
        expect(todos).toHaveLength 1
        expect(todos[0].type).toBe 'TODO'
        expect(todos[0].text).toBe 'Comment in C'
        expect(todos[0].file).toBe 'sample.c'

  describe 'when the tree view context menu is selected', ->
    beforeEach ->
      atom.commands.dispatch(workspaceElement, 'todo-show:find-in-workspace')
      waitsForPromise -> activationPromise
      runs ->
        waitsFor ->
          !showTodoModule.showTodoView.isSearching() and showTodoModule.showTodoView.isVisible()

    it 'searches for todos in the selected folder', ->
      expect(showTodoModule.collection.getTodosCount()).toBe nTodos

      event =
        target:
          getAttribute: ->
            path.join(__dirname, 'fixtures/sample1/sample.c')
      showTodoModule.show(undefined, event)

      waitsFor -> !showTodoModule.showTodoView.isSearching()
      runs ->
        expect(showTodoModule.collection.getCustomPath()).toBe 'sample.c'
        expect(showTodoModule.collection.scope).toBe 'custom'
        expect(showTodoModule.collection.getTodosCount()).toBe 1

    it 'handles missing path in event argument', ->
      event =
        target:
          getAttribute: ->
            undefined
      showTodoModule.show(undefined, event)

      waitsFor -> !showTodoModule.showTodoView.isSearching()
      runs ->
        expect(showTodoModule.collection.getTodosCount()).toBe nTodos

  describe 'status bar indicator', ->
    todoIndicatorClass = '.status-bar .todo-status-bar-indicator'

    it 'shows the current number of todos', ->
      atom.packages.activatePackage 'status-bar'

      executeCommand ->
        expect(workspaceElement.querySelector(todoIndicatorClass)).not.toExist()
        atom.config.set('todo-show.statusBarIndicator', true)
        expect(workspaceElement.querySelector(todoIndicatorClass)).toExist()

        nTodos = showTodoModule.showTodoView.getTodosCount()
        expect(nTodos).not.toBe 0
        indicatorElement = workspaceElement.querySelector(todoIndicatorClass)
        expect(indicatorElement.innerText).toBe nTodos.toString()
