{View} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

module.exports =
class TabNumbersView extends View
  nTodos: 0

  @content: ->
    @div class: 'todo-status-bar-indicator inline-block', tabindex: -1, =>
      @a class: 'inline-block', =>
        @span class: 'icon icon-checklist'
        @span outlet: 'todoCount'

  initialize: (@collection) ->
    @disposables = new CompositeDisposable
    @on 'click', this.element, @activateTodoPackage

    @update()
    @disposables.add @collection.onDidFinishSearch @update

  destroy: ->
    @disposables.dispose()
    @detach()

  update: =>
    @nTodos = @collection.getTodosCount()
    @todoCount.text(@nTodos)

    @toolTipDisposable?.dispose()
    @toolTipDisposable = atom.tooltips.add @element, title: "#{@nTodos} TODOs"

  activateTodoPackage: ->
    atom.commands.dispatch(this, 'todo-show:find-in-workspace')
