{View} = require 'atom-space-pen-views'

class BaseView extends View
  initialize: ->
    @handleEvents()

  destroy: ->
    @detach()

  # Open document and move cursor to positon
  moveCursorTo: (cursorCoords) ->
    lineNumber = parseInt(cursorCoords[0])
    charNumber = parseInt(cursorCoords[1])

    if textEditor = atom.workspace.getActiveTextEditor()
      position = [lineNumber, charNumber]
      textEditor.setCursorBufferPosition(position, autoscroll: false)
      textEditor.scrollToCursorPosition(center: true)

  # Open a new window, and load the file that we need.
  # we call this from the results view. This will open the result file in the left pane.
  openPath: (filePath, cursorCoords) ->
    return unless filePath
    atom.workspace.open(filePath, split: 'left').done =>
      @moveCursorTo(cursorCoords)

  handleEvents: ->
    @on 'click', '.todo-url',  (e) =>
      link = e.target
      @openPath(link.dataset.uri, link.dataset.coords.split(','))

class TodoRegexView extends BaseView
  @content: (matches) ->
    @section =>
      @h1 =>
        @span "#{matches[0].title} "
        @span class: 'regex', matches[0].regex
      @table =>
        for match in matches
          @tr =>
            @td match.matchText
            @td =>
              @a class: 'todo-url', 'data-uri': match.path,
              'data-coords': match.rangeString, match.relativePath

class TodoFileView extends BaseView
  @content: (matches) ->
    @section =>
      @h1 =>
        @span "#{matches[0].relativePath}"
      @table =>
        for match in matches
          @tr =>
            @td match.matchText
            @td =>
              @a class: 'todo-url', 'data-uri': match.path,
              'data-coords': match.rangeString, match.title

class TodoNoneView extends BaseView
  @content: (matches) ->
    @section =>
      @h1 "All Matches"
      @table =>
        for match in matches
          @tr =>
            @td =>
              @span "#{match.matchText} "
              @i "(#{match.title})"
            @td =>
              @a class: 'todo-url', 'data-uri': match.path,
              'data-coords': match.rangeString, match.relativePath

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

module.exports = {TodoRegexView, TodoFileView, TodoNoneView, TodoEmptyView}
