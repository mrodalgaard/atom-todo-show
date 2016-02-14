{CompositeDisposable} = require 'atom'
{View} = require 'atom-space-pen-views'

class ItemView extends View
  @content: (item) ->
    @span class: 'badge badge-large', 'data-id': item, item

class CodeView extends View
  @content: (item) ->
    @code item

module.exports =
class ShowTodoView extends View
  @content: ->
    @div outlet: 'todoOptions', class: 'todo-options', =>
      @div class: 'option', =>
        @h2 'On Table'
        @div outlet: 'itemsOnTable', class: 'block items-on-table'

      @div class: 'option', =>
        @h2 'Off Table'
        @div outlet: 'itemsOffTable', class: 'block items-off-table'

      @div class: 'option', =>
        @h2 'Find Todos'
        @div outlet: 'findTodoDiv'

      @div class: 'option', =>
        @h2 'Find Regex'
        @div outlet: 'findRegexDiv'

      @div class: 'option', =>
        @h2 'Ignore Paths'
        @div outlet: 'ignorePathDiv'

      @div class: 'option', =>
        @h2 ''
        @div class: 'btn-group', =>
          @button outlet: 'configButton', class: 'btn', "Go to Config"
          @button outlet: 'closeButton', class: 'btn', "Close Options"

  initialize: (@collection) ->
    @disposables = new CompositeDisposable
    @handleEvents()
    @updateUI()

  handleEvents: ->
    @configButton.on 'click', ->
      atom.workspace.open 'atom://config/packages/todo-show'
    @closeButton.on 'click', => @parent().slideToggle()

  detach: ->
    @disposables.dispose()

  updateShowInTable: =>
    showInTable = @sortable.toArray()
    atom.config.set('todo-show.showInTable', showInTable)

  updateUI: ->
    tableItems = atom.config.get('todo-show.showInTable')
    for item in @collection.getAvailableTableItems()
      if tableItems.indexOf(item) is -1
        @itemsOffTable.append new ItemView(item)
      else
        @itemsOnTable.append new ItemView(item)

    Sortable = require 'sortablejs'

    @sortable = Sortable.create(
      @itemsOnTable.context
      group: 'tableItems'
      ghostClass: 'ghost'
      onSort: @updateShowInTable
    )

    Sortable.create(
      @itemsOffTable.context
      group: 'tableItems'
      ghostClass: 'ghost'
    )

    for todo in todos = atom.config.get('todo-show.findTheseTodos')
      @findTodoDiv.append new CodeView(todo)

    regex = atom.config.get('todo-show.findUsingRegex')
    @findRegexDiv.append new CodeView(regex.replace('${TODOS}', todos.join('|')))

    for path in atom.config.get('todo-show.ignoreThesePaths')
      @ignorePathDiv.append new CodeView(path)
