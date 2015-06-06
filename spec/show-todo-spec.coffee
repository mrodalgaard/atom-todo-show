
path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'

describe 'ShowTodo opening panes and executing commands', ->
  [workspaceElement, activationPromise, showTodoModule] = []

  # needed to activate packages that are using activationCommands
  # and wait for loading to stop
  executeCommand = (callback) ->
    atom.commands.dispatch(workspaceElement, 'todo-show:find-in-project')
    waitsForPromise -> activationPromise
    runs ->
      showTodoModule = atom.packages.loadedPackages['todo-show'].mainModule
      waitsFor ->
        !showTodoModule.showTodoView.loading
      runs(callback)

  beforeEach ->
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]
    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)
    activationPromise = atom.packages.activatePackage 'todo-show'

  describe 'when the show-todo:find-in-project event is triggered', ->
    it 'attaches and then detaches the pane view', ->
      expect(atom.packages.loadedPackages['todo-show']).toBeDefined()
      expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

      # open todo-show
      executeCommand ->
        pane = atom.workspace.paneForItem(showTodoModule.showTodoView)
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(pane.parent.orientation).toBe 'horizontal'

        # close todo-show again
        executeCommand ->
          expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

    it 'can open in vertical split', ->
      atom.config.set 'todo-show.openListInDirection', 'down'

      executeCommand ->
        pane = atom.workspace.paneForItem(showTodoModule.showTodoView)
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(pane.parent.orientation).toBe 'vertical'

        executeCommand ->
          expect(workspaceElement.querySelector('.show-todo-preview')).not.toExist()

    it 'can open ontop of current view', ->
      atom.config.set 'todo-show.openListInDirection', 'ontop'

      executeCommand ->
        pane = atom.workspace.paneForItem(showTodoModule.showTodoView)
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(pane.parent.orientation).not.toExist()

  describe 'when config changes', ->
    configRegexes = 'todo-show.findTheseRegexes'
    configPaths = 'todo-show.ignoreThesePaths'

    # TODO: Test results from change of configs instead of just setting it

    beforeEach ->
      executeCommand ->

    it 'has default configs set', ->
      defaultRegexes = atom.config.get(configRegexes)
      expect(defaultRegexes).toBeDefined()
      expect(defaultRegexes.length).toBeGreaterThan 3

      defaultPaths = atom.config.get(configPaths)
      expect(defaultPaths).toBeDefined()
      expect(defaultPaths.length).toBeGreaterThan 2

    it 'should be able to override defaults', ->
      newRegexes = ['New Regex', '/ReGeX/g']
      atom.config.set(configRegexes, newRegexes)
      expect(atom.config.get(configRegexes)).toEqual(newRegexes)

      newPaths = ['/foobar/']
      atom.config.set(configPaths, newPaths)
      expect(atom.config.get(configPaths)).toEqual(newPaths)

  describe 'when save-as button is clicked', ->
    it 'saves the list in markdown and opens it', ->
      outputPath = temp.path(suffix: '.md')
      expectedFilePath = atom.project.getDirectories()[0].resolve('../saved-output.md')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()

      expect(fs.isFileSync(outputPath)).toBe false

      executeCommand ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        workspaceElement.querySelector('.show-todo-preview .todo-save-as').click()

      waitsFor ->
        fs.existsSync(outputPath) && atom.workspace.getActiveTextEditor()?.getPath() is fs.realpathSync(outputPath)

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput

  describe 'when core:refresh is triggered', ->
    it 'refreshes the list', ->
      executeCommand ->
        atom.commands.dispatch workspaceElement.querySelector('.show-todo-preview'), 'core:refresh'

        expect(showTodoModule.showTodoView.loading).toBe true

        waitsFor ->
          !showTodoModule.showTodoView.loading

        runs ->
          expect(showTodoModule.showTodoView.loading).toBe false

  describe 'when the show-todo:find-in-open-files event is triggered', ->
    beforeEach ->
      atom.commands.dispatch(workspaceElement, 'todo-show:find-in-open-files')
      waitsForPromise -> activationPromise
      runs ->
        showTodoModule = atom.packages.loadedPackages['todo-show'].mainModule
        waitsFor ->
          !showTodoModule.showTodoView.loading

    it 'does not show any results with no open files', ->
      expect(showTodoModule.showTodoView.regexes.length).toBe 0

    it 'only shows todos from open files', ->
      waitsForPromise ->
        atom.workspace.open 'sample.c'

      runs ->
        atom.commands.dispatch workspaceElement.querySelector('.show-todo-preview'), 'core:refresh'

        waitsFor ->
          !showTodoModule.showTodoView.loading

        runs ->
          todoRegex = showTodoModule.showTodoView.regexes[0]
          expect(todoRegex.title).toBe 'TODOs'
          expect(todoRegex.results.length).toBe 1
          expect(todoRegex.results[0].matches.length).toBe 1
          expect(todoRegex.results[0].matches[0].matchText).toBe 'Comment in C'
