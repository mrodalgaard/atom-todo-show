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
            when 'Message'
              @span todo.matchText
            when 'Text'
              @span todo.lineText
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
  @content: ->
    @section =>
      @h1 "No results"
      @table =>
        @tr =>
          @td =>
            @h5 "Did not find any todos. Searched for:"
            @ul =>
              for regex in atom.config.get('todo-show.findTheseRegexes') by 2
                @li regex
            @h5 "Use your configuration to add more patterns."

module.exports = {TableHeaderView, TodoView, TodoEmptyView}
