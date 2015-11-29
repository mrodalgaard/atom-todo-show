{CompositeDisposable} = require 'atom'
{View, $} = require 'atom-space-pen-views'

{TableHeaderView, TodoView, TodoEmptyView} = require './todo-item-view'

module.exports =
class ShowTodoView extends View
  @content: ->
    @div class: 'todo-table', tabindex: -1, =>
      @table outlet: 'table', class: 'todo-table'

  initialize: (@model) ->
    @disposables = new CompositeDisposable
    @disposables.add atom.config.onDidChange 'todo-show.showInTable', ({newValue, oldValue}) =>
      @showInTable = newValue
      @renderTable()

    @disposables.add atom.config.onDidChange 'todo-show.sortBy', ({newValue, oldValue}) =>
      @sort(@sortBy = newValue, @sortAsc)

    @disposables.add atom.config.onDidChange 'todo-show.sortAscending', ({newValue, oldValue}) =>
      @sort(@sortBy, @sortAsc = newValue)

    @handleEvents()

  handleEvents: ->
    # @disposables.add @model.onDidAddTodo @renderTodo
    @disposables.add @model.onDidFinishSearch @initTable
    @disposables.add @model.onDidRemoveTodo @removeTodo
    @disposables.add @model.onDidClear @clearTodos
    @disposables.add @model.onDidSortTodos @renderTable
    @disposables.add @model.onDidChangeSearchScope => @model.search()

    @on 'click', 'th', @tableHeaderClicked

  detached: ->
    @disposables.dispose()
    @empty()

  initTable: =>
    @showInTable = atom.config.get('todo-show.showInTable')
    @sortBy = atom.config.get('todo-show.sortBy')
    @sortAsc = atom.config.get('todo-show.sortAscending')
    @sort(@sortBy, @sortAsc)

  renderTableHeader: ->
    @table.append new TableHeaderView(@showInTable, {@sortBy, @sortAsc})

  tableHeaderClicked: (e) =>
    item = e.target.innerText
    sortAsc = if @sortBy is item then !@sortAsc else true

    atom.config.set('todo-show.sortBy', item)
    atom.config.set('todo-show.sortAscending', sortAsc)

  renderTodo: (todo) =>
    @table.append new TodoView(@showInTable, todo)

  removeTodo: (todo) ->
    console.log 'removeTodo'

  clearTodos: =>
    @table.empty()

  renderTable: =>
    @clearTodos()
    @renderTableHeader()

    for todo in todos = @model.getTodos()
      @renderTodo(todo)
    @table.append new TodoEmptyView(@showInTable) unless todos.length

  sort: (sortBy, sortAsc) ->
    @model.sortTodos(sortBy: sortBy, sortAsc: sortAsc)
