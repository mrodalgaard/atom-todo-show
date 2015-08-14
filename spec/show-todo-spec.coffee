
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

    it 'can open ontop of current view', ->
      atom.config.set 'todo-show.openListInDirection', 'ontop'

      executeCommand ->
        pane = atom.workspace.paneForItem(showTodoModule.showTodoView)
        expect(workspaceElement.querySelector('.show-todo-preview')).toExist()
        expect(pane.parent.orientation).not.toExist()

    it 'has visible elements in view', ->
      executeCommand ->
        element = showTodoModule.showTodoView.find('a').last()
        expect(element.text()).toEqual 'sample.js'
        expect(element.isVisible()).toBe true

    it 'persists pane width', ->
      executeCommand ->
        pane = atom.workspace.paneForItem showTodoModule.showTodoView
        originalFlex = pane.getFlexScale()
        newFlex = originalFlex * 1.1
        expect(typeof originalFlex).toEqual "number"

        pane.setFlexScale(newFlex)
        executeCommand ->
          pane = atom.workspace.paneForItem showTodoModule.showTodoView
          expect(pane).not.toExist()
          executeCommand ->
            pane = atom.workspace.paneForItem showTodoModule.showTodoView
            expect(pane.getFlexScale()).toEqual newFlex
            pane.setFlexScale(originalFlex)

    it 'does not persist pane width if asked not to', ->
      atom.config.set('todo-show.rememberViewSize', false)

      executeCommand ->
        pane = atom.workspace.paneForItem showTodoModule.showTodoView
        originalFlex = pane.getFlexScale()
        newFlex = originalFlex * 1.1
        expect(typeof originalFlex).toEqual "number"

        pane.setFlexScale(newFlex)
        executeCommand ->
          executeCommand ->
            pane = atom.workspace.paneForItem showTodoModule.showTodoView
            expect(pane.getFlexScale()).not.toEqual newFlex
            expect(pane.getFlexScale()).toEqual originalFlex

    it 'persists horizontal pane height', ->
      atom.config.set('todo-show.openListInDirection', 'down')

      executeCommand ->
        pane = atom.workspace.paneForItem showTodoModule.showTodoView
        originalFlex = pane.getFlexScale()
        newFlex = originalFlex * 1.1
        expect(typeof originalFlex).toEqual "number"

        pane.setFlexScale(newFlex)
        executeCommand ->
          pane = atom.workspace.paneForItem showTodoModule.showTodoView
          expect(pane).not.toExist()
          executeCommand ->
            pane = atom.workspace.paneForItem showTodoModule.showTodoView
            expect(pane.getFlexScale()).toEqual newFlex
            pane.setFlexScale(originalFlex)

    it 'groups matches by regex titles', ->
      executeCommand ->
        headers = showTodoModule.showTodoView.find('h1')
        expect(headers).toHaveLength 8
        expect(headers.eq(0).text().split(' ')[0]).toBe 'FIXMEs'
        expect(headers.eq(1).text().split(' ')[0]).toBe 'TODOs'
        expect(headers.eq(7).text().split(' ')[0]).toBe 'REVIEWs'

    it 'can group matches by filename', ->
      atom.config.set 'todo-show.groupMatchesBy', 'file'
      executeCommand ->
        headers = showTodoModule.showTodoView.find('h1')
        expect(headers).toHaveLength 2
        expect(headers.eq(0).text().split(' ')[0]).toBe 'sample.c'
        expect(headers.eq(1).text().split(' ')[0]).toBe 'sample.js'

        t1 = showTodoModule.showTodoView.find('table').eq(0).find('td').first().text()
        t2 = showTodoModule.showTodoView.find('table').eq(1).find('td').first().text()
        expect(t1).toBe 'Comment in C'
        expect(t2).toBe 'Add more annnotations :)'

    it 'can group matches by text (no grouping)', ->
      atom.config.set 'todo-show.groupMatchesBy', 'none'
      executeCommand ->
        expect(showTodoModule.showTodoView.find('h1')).toHaveLength 1
        expect(showTodoModule.showTodoView.find('table')).toHaveLength 1

        t1 = showTodoModule.showTodoView.find('td').eq(0).text()
        t2 = showTodoModule.showTodoView.find('td').eq(-2).text()
        expect(t1).toBe 'Add more annnotations :) (FIXMEs)'
        expect(t2.substring(0,3)).toBe 'two'

  describe 'when save-as button is clicked', ->
    it 'saves the list in markdown and opens it', ->
      outputPath = temp.path(suffix: '.md')
      expectedFilePath = atom.project.getDirectories()[0].resolve('../saved-output.md')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()

      expect(fs.isFileSync(outputPath)).toBe false

      executeCommand ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        showTodoModule.showTodoView.saveAs()

      waitsFor ->
        fs.existsSync(outputPath) && atom.workspace.getActiveTextEditor()?.getPath() is fs.realpathSync(outputPath)

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput

    it 'saves the list in markdown grouped by filename', ->
      outputPath = temp.path(suffix: '.md')
      expectedFilePath = atom.project.getDirectories()[0].resolve('../saved-output-grouped.md')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()

      atom.config.set 'todo-show.findTheseRegexes', ['TODOs', '/\\b@?TODO:?\\s(.+$)/g']
      atom.config.set 'todo-show.groupMatchesBy', 'file'

      expect(fs.isFileSync(outputPath)).toBe false

      executeCommand ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        showTodoModule.showTodoView.saveAs()

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
      element = showTodoModule.showTodoView.find('h1').last()

      expect(showTodoModule.showTodoView.matches.length).toBe 0
      expect(element.text()).toContain 'No results'
      expect(element.isVisible()).toBe true

    it 'only shows todos from open files', ->
      waitsForPromise ->
        atom.workspace.open 'sample.c'

      runs ->
        atom.commands.dispatch workspaceElement.querySelector('.show-todo-preview'), 'core:refresh'

        waitsFor ->
          !showTodoModule.showTodoView.loading

        runs ->
          todoMatch = showTodoModule.showTodoView.matches[0]
          expect(showTodoModule.showTodoView.matches).toHaveLength 1
          expect(todoMatch.title).toBe 'TODOs'
          expect(todoMatch.matchText).toBe 'Comment in C'
          expect(todoMatch.relativePath).toBe 'sample.c'
