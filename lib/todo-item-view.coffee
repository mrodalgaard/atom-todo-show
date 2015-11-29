{View} = require 'atom-space-pen-views'

class TableHeaderView extends View
  @content: (showInTable, {sortBy, sortAsc}) ->
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
  @content: (showInTable, todo) ->
    @tr =>
      for item in showInTable
        @td =>
          switch item
            when 'All'
              @span todo.lineText
            when 'Text'
              @span todo.matchText
            when 'Type'
              @i todo.title
            when 'Range'
              @i todo.rangeString
            when 'Line'
              @i todo.line
            when 'Regex'
              @code todo.regex
            when 'File'
              @a todo.relativePath

  initialize: (showInTable, @todo) ->
    @handleEvents()

  destroy: ->
    @detach()

  handleEvents: ->
    @on 'click', 'td', @openPath

  openPath: =>
    return unless todo = @todo
    atom.workspace.open(todo.path, split: 'left').then ->
      if textEditor = atom.workspace.getActiveTextEditor()
        position = [todo.range[0][0], todo.range[0][1]]
        textEditor.setCursorBufferPosition(position, autoscroll: false)
        textEditor.scrollToCursorPosition(center: true)

class TodoEmptyView extends View
  @content: (showInTable) ->
    @tr =>
      @td colspan: showInTable.length, =>
        @p "No results..."

module.exports = {TableHeaderView, TodoView, TodoEmptyView}
