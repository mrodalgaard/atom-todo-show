# Tests in this file are all about ensuring the command works properly and loads the proper panes...

fs = require 'fs-plus'
temp = require 'temp'

describe 'ShowTodo', ->
  [workspaceElement, activationPromise, showTodoModule] = []

  # needed to activate packages that are using activationCommands
  executeCommand = (callback) ->
    atom.commands.dispatch(workspaceElement, 'todo-show:find-in-project')
    waitsForPromise -> activationPromise
    runs(callback)

  beforeEach ->
    atom.project.setPaths([path.join(__dirname, 'fixtures/sample1')])
    workspaceElement = atom.views.getView(atom.workspace)
    #jasmine.attachToDOM(workspaceElement)
    activationPromise = atom.packages.activatePackage('todo-show')
    showTodoModule = atom.packages.loadedPackages["todo-show"].mainModule


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
  
  describe 'when config changes', ->
    configRegexes = 'todo-show.findTheseRegexes'
    configPaths = 'todo-show.ignoreThesePaths'
    
    # TODO: Test results from change of configs instead of just setting it
    
    beforeEach ->
      executeCommand ->
    
    it 'has default configs set', ->
      defaultRegexes = atom.config.get(configRegexes)
      expect(defaultRegexes).toBeDefined()
      expect(defaultRegexes.length).toBeGreaterThan(3)
      
      defaultPaths = atom.config.get(configPaths)
      expect(defaultPaths).toBeDefined()
      expect(defaultPaths.length).toBeGreaterThan(2)
    
    it 'should be able to override defaults', ->
      newRegexes = ['New Regex', '/ReGeX/g']
      atom.config.set(configRegexes, newRegexes)
      expect(atom.config.get(configRegexes)).toEqual(newRegexes)
      
      newPaths = ['/foobar/']
      atom.config.set(configPaths, newPaths)
      expect(atom.config.get(configPaths)).toEqual(newPaths)
  
  describe 'when core:save-as is triggered', ->
    beforeEach ->
      executeCommand ->
    
    it 'saves the list in markdown and opens it', ->
      outputPath = temp.path(suffix: '.md')
      expectedFilePath = atom.project.getDirectories()[0].resolve('../saved-output.md')
      expectedOutput = fs.readFileSync(expectedFilePath).toString()
      
      expect(fs.isFileSync(outputPath)).toBe false
      
      waitsFor ->
        !showTodoModule.showTodoView.loading
      
      runs ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        atom.commands.dispatch workspaceElement.querySelector('.show-todo-preview'), 'core:save-as'
        
      waitsFor ->
        fs.existsSync(outputPath) && atom.workspace.getActiveTextEditor()?.getPath() is fs.realpathSync(outputPath)

      runs ->
        expect(fs.isFileSync(outputPath)).toBe true
        expect(atom.workspace.getActiveTextEditor().getText()).toBe expectedOutput
        
        
        
        
