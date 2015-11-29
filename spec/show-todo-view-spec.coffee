path = require 'path'

ShowTodoView = require '../lib/show-todo-view'
TodosModel = require '../lib/todos-model'

describe "Show Todo View", ->
  [showTodoView, model] = []

  beforeEach ->
    model = new TodosModel
    uri = 'atom://todo-show/todos'
    showTodoView = new ShowTodoView(model, uri)
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]

  describe "Basic view properties", ->
    it "has a title, uri, etc.", ->
      expect(showTodoView.getTitle()).toEqual 'Todo-Show Results'
      expect(showTodoView.getIconName()).toEqual 'checklist'
      expect(showTodoView.getURI()).toEqual 'atom://todo-show/todos'
      expect(showTodoView.find('.btn-group')).toExist()
