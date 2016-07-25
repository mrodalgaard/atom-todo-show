path = require 'path'

ShowTodoView = require '../lib/todo-view'
TodosCollection = require '../lib/todo-collection'

sample1Path = path.join(__dirname, 'fixtures/sample1')
sample2Path = path.join(__dirname, 'fixtures/sample2')

describe "Show Todo View", ->
  [showTodoView, collection] = []

  beforeEach ->
    atom.config.set 'todo-show.findTheseTodos', ['TODO']
    atom.config.set 'todo-show.findUsingRegex', '/\\b(${TODOS}):?\\d*($|\\s.*$)/g'

    atom.project.setPaths [sample1Path]
    collection = new TodosCollection
    uri = 'atom://todo-show/todos'
    showTodoView = new ShowTodoView(collection, uri)
    waitsFor -> !showTodoView.isSearching()

  describe "View properties", ->
    it "has a title, uri, etc.", ->
      expect(showTodoView.getIconName()).toEqual 'checklist'
      expect(showTodoView.getURI()).toEqual 'atom://todo-show/todos'
      expect(showTodoView.find('.btn-group')).toExist()

    it "updates view info", ->
      getInfo = -> showTodoView.todoInfo.text()

      count = showTodoView.getTodosCount()
      expect(getInfo()).toBe "Found #{count} results in workspace"
      showTodoView.collection.search()
      expect(getInfo()).toBe "Found ... results in workspace"

      waitsFor -> !showTodoView.isSearching()
      runs ->
        expect(getInfo()).toBe "Found #{count} results in workspace"
        showTodoView.collection.todos = ['a single todo']
        showTodoView.updateInfo()
        expect(getInfo()).toBe "Found 1 result in workspace"

    it "updates view info details", ->
      getInfo = -> showTodoView.todoInfo.text()

      collection.setSearchScope('project')
      waitsFor -> !showTodoView.isSearching()
      runs ->
        expect(getInfo()).toBe "Found 3 results in project sample1"

        collection.setSearchScope('open')
        waitsFor -> !showTodoView.isSearching()
        runs ->
          expect(getInfo()).toBe "Found 0 results in open files"

  describe "Automatic update of todos", ->
    it "refreshes on save", ->
      expect(showTodoView.getTodos()).toHaveLength 3

      waitsForPromise -> atom.workspace.open 'temp.txt'
      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editor.setText("# TODO: Test")
        editor.save()

        waitsFor -> !showTodoView.isSearching()
        runs ->
          expect(showTodoView.getTodos()).toHaveLength 4
          editor.setText("")
          editor.save()

          waitsFor -> !showTodoView.isSearching()
          runs ->
            expect(showTodoView.getTodos()).toHaveLength 3

    it "updates on search scope change", ->
      expect(showTodoView.isSearching()).toBe false
      expect(collection.getSearchScope()).toBe 'workspace'
      expect(showTodoView.getTodos()).toHaveLength 3
      expect(collection.toggleSearchScope()).toBe 'project'
      expect(showTodoView.isSearching()).toBe true

      waitsFor -> !showTodoView.isSearching()
      runs ->
        expect(showTodoView.getTodos()).toHaveLength 3
        expect(collection.toggleSearchScope()).toBe 'open'
        expect(showTodoView.isSearching()).toBe true

        waitsFor -> !showTodoView.isSearching()
        runs ->
          expect(showTodoView.getTodos()).toHaveLength 0
          expect(collection.toggleSearchScope()).toBe 'active'
          expect(showTodoView.isSearching()).toBe true

          waitsFor -> !showTodoView.isSearching()
          runs ->
            expect(showTodoView.getTodos()).toHaveLength 0
            expect(collection.toggleSearchScope()).toBe 'workspace'
            expect(showTodoView.isSearching()).toBe true

    it "handles search scope 'project'", ->
      atom.project.addPath sample2Path

      waitsForPromise ->
        atom.workspace.open path.join(sample2Path, 'sample.txt')
      runs ->
        collection.setSearchScope 'workspace'

        waitsFor -> !showTodoView.isSearching()
        runs ->
          expect(showTodoView.getTodos()).toHaveLength 9
          collection.setSearchScope 'project'
          expect(showTodoView.isSearching()).toBe true

          waitsFor -> !showTodoView.isSearching()
          runs ->
            expect(showTodoView.getTodos()).toHaveLength 6

            waitsForPromise ->
              atom.workspace.open path.join(sample1Path, 'sample.c')
            waitsFor -> !showTodoView.isSearching()
            runs ->
              expect(showTodoView.getTodos()).toHaveLength 3

    it "handles search scope 'open'", ->
      waitsForPromise -> atom.workspace.open 'sample.c'
      waitsFor -> !showTodoView.isSearching()
      runs ->
        expect(showTodoView.getTodos()).toHaveLength 3
        collection.setSearchScope 'open'
        expect(showTodoView.isSearching()).toBe true

        waitsFor -> !showTodoView.isSearching()
        runs ->
          expect(showTodoView.getTodos()).toHaveLength 1

          waitsForPromise -> atom.workspace.open 'sample.js'
          waitsFor -> !showTodoView.isSearching()
          runs ->
            expect(showTodoView.getTodos()).toHaveLength 3
            atom.workspace.getActivePane().itemAtIndex(0).destroy()

            waitsFor -> !showTodoView.isSearching()
            runs ->
              expect(showTodoView.getTodos()).toHaveLength 2

    it "handles search scope 'active'", ->
      waitsForPromise -> atom.workspace.open 'sample.c'
      waitsForPromise -> atom.workspace.open 'sample.js'
      waitsFor -> !showTodoView.isSearching()
      runs ->
        expect(showTodoView.getTodos()).toHaveLength 3
        collection.setSearchScope 'active'
        expect(showTodoView.isSearching()).toBe true

        waitsFor -> !showTodoView.isSearching()
        runs ->
          expect(showTodoView.getTodos()).toHaveLength 2
          atom.workspace.getActivePane().activateItemAtIndex 0

          waitsFor -> !showTodoView.isSearching()
          runs ->
            expect(showTodoView.getTodos()).toHaveLength 1
