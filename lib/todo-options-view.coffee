{CompositeDisposable} = require 'atom'
{View} = require 'atom-space-pen-views'

class ItemView extends View
  @content: (item) ->
    @span class: 'badge badge-large', 'data-id': item, item

class CodeView extends View
  @content: (item) ->
    @code item

class RegexView extends View
  @content: (title, regex) ->
    @div =>
      @span "#{title}: "
      @code regex

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
        @h2 'Regexes'
        @div class: 'regex', outlet: 'regexString'

      @div class: 'option', =>
        @h2 'Ignore Paths'
        @div class: 'ignores', outlet: 'ignoresString'

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

    regexes = atom.config.get('todo-show.findTheseRegexes')
    for regex, i in regexes by 2
      @regexString.append new RegexView(regex, regexes[i+1])

    for path in atom.config.get('todo-show.ignoreThesePaths')
      @ignoresString.append new CodeView(path)
