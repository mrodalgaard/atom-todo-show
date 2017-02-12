path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'

describe 'ShowTodo opening panes and executing commands', ->
  [workspaceElement, activationPromise, showTodoModule, showTodoPane] = []

  # Needed to activate packages that are using activationCommands
  # and wait for loading to stop
  executeCommand = (callback) ->
    wasVisible = showTodoModule?.showTodoView.isVisible()
    atom.commands.dispatch(workspaceElement, 'todo-show:find-in-workspace')
    waitsForPromise -> activationPromise
    runs ->
      waitsFor ->
        return !showTodoModule.showTodoView.isVisible() if wasVisible
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

  describe 'when the show-todo:find-in-workspace event is triggered', ->
    it 'attaches and then detaches the pane view', ->
      expect(atom.packages.loadedPackages['todo-show']).toBeDefined()
      expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

      # open todo-show
      executeCommand ->
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(showTodoPane.parent.orientation).toBe 'horizontal'

        # close todo-show again
        executeCommand ->
          expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

    it 'can open in vertical split', ->
      atom.config.set 'todo-show.openListInDirection', 'down'

      executeCommand ->
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(showTodoPane.parent.orientation).toBe 'vertical'

    it 'can open ontop of current view', ->
      atom.config.set 'todo-show.openListInDirection', 'ontop'

      executeCommand ->
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(showTodoPane.parent.orientation).not.toExist()

    it 'has visible elements in view', ->
      executeCommand ->
        element = showTodoModule.showTodoView.find('td').last()
        expect(element.text()).toEqual 'sample.js'
        expect(element.isVisible()).toBe true

    it 'persists pane width', ->
      executeCommand ->
        originalFlex = showTodoPane.getFlexScale()
        newFlex = originalFlex * 1.1
        expect(typeof originalFlex).toEqual "number"
        expect(showTodoModule.showTodoView).toBeVisible()
        showTodoPane.setFlexScale(newFlex)

        executeCommand ->
          expect(showTodoPane).not.toExist()
          expect(showTodoModule.showTodoView).not.toBeVisible()

          executeCommand ->
            expect(showTodoPane.getFlexScale()).toEqual newFlex
            showTodoPane.setFlexScale(originalFlex)

    it 'does not persist pane width if asked not to', ->
      atom.config.set('todo-show.rememberViewSize', false)

      executeCommand ->
        originalFlex = showTodoPane.getFlexScale()
        newFlex = originalFlex * 1.1
        expect(typeof originalFlex).toEqual "number"

        showTodoPane.setFlexScale(newFlex)
        executeCommand ->
          executeCommand ->
            expect(showTodoPane.getFlexScale()).not.toEqual newFlex
            expect(showTodoPane.getFlexScale()).toEqual originalFlex

    it 'persists horizontal pane height', ->
      atom.config.set('todo-show.openListInDirection', 'down')

      executeCommand ->
        originalFlex = showTodoPane.getFlexScale()
        newFlex = originalFlex * 1.1
        expect(typeof originalFlex).toEqual "number"

        showTodoPane.setFlexScale(newFlex)
        executeCommand ->
          expect(showTodoPane).not.toExist()
          executeCommand ->
            expect(showTodoPane.getFlexScale()).toEqual newFlex
            showTodoPane.setFlexScale(originalFlex)

  describe 'when the show-todo:find-in-workspace event is triggered', ->
    it 'activates', ->
      expect(atom.packages.loadedPackages['todo-show']).toBeDefined()
      expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

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
        expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput

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

  describe 'when the show-todo:find-in-open-files event is triggered', ->
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
