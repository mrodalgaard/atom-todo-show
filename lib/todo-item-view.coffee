{View} = require 'atom-space-pen-views'

class TableHeaderView extends View
  @content: (showInTable = [], {sortBy, sortAsc}) ->
    @tr =>
      for item in showInTable
        @th item, =>
          if item is sortBy and sortAsc
            @div class: 'sort-asc icon-triangle-down active'
          else
            @div class: 'sort-asc icon-triangle-down'
          if item is sortBy and not sortAsc
            @div class: 'sort-desc icon-triangle-up active'
          else
            @div class: 'sort-desc icon-triangle-up'

class TodoView extends View
  @content: (showInTable = [], todo) ->
    @tr =>
      for item in showInTable
        @td =>
          switch item
            when 'All'   then @span todo.all
            when 'Text'  then @span todo.text
            when 'Type'  then @i todo.type
            when 'Range' then @i todo.range
            when 'Line'  then @i todo.line
            when 'Regex' then @code todo.regex
            when 'Path'  then @a todo.path
            when 'File'  then @a todo.file
            when 'Tags'  then @i todo.tags
            when 'Id'    then @i todo.id
            when 'Project' then @a todo.project

  initialize: (showInTable, @todo) ->
    @handleEvents()

  destroy: ->
    @detach()

  handleEvents: ->
    @on 'click', 'td', @openPath

  openPath: =>
    return unless @todo and @todo.loc
    position = [@todo.position[0][0], @todo.position[0][1]]

    atom.workspace.open(@todo.loc, {
      split: @getSplitDirection()
      pending: atom.config.get('core.allowPendingPaneItems') or false
    }).then ->
      # Setting initialColumn/Line does not always center view
      if textEditor = atom.workspace.getActiveTextEditor()
        textEditor.setCursorBufferPosition(position, autoscroll: false)
        textEditor.scrollToCursorPosition(center: true)

  getSplitDirection: ->
    switch atom.config.get('todo-show.openListInDirection')
      when 'up' then 'down'
      when 'down' then 'up'
      when 'left' then 'right'
      else 'left'

class TodoEmptyView extends View
  @content: (showInTable = []) ->
    @tr =>
      @td colspan: showInTable.length, =>
        @p "No results..."

module.exports = {TableHeaderView, TodoView, TodoEmptyView}
