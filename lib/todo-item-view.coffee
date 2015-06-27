{View} = require 'atom-space-pen-views'

module.exports =
class TodoItemView extends View
  @content: (regex) ->
    @section =>
      @h1 =>
        @span "#{regex.title} "
        @span class: 'regex', regex.regex
      @table =>
        for result in regex.results
          for match in result.matches
            @tr =>
              @td match.matchText
              @td =>
                @a class: 'todo-url', 'data-uri': result.filePath,
                'data-coords': match.rangeString, result.relativePath

  initialize: ->
    @handleEvents()

  destroy: ->
    @detach()

  handleEvents: ->
    @on 'click', '.todo-url',  (e) =>
      link = e.target
      @openPath(link.dataset.uri, link.dataset.coords.split(','))

  # Open a new window, and load the file that we need.
  # we call this from the results view. This will open the result file in the left pane.
  openPath: (filePath, cursorCoords) ->
    return unless filePath

    atom.workspace.open(filePath, split: 'left').done =>
      @moveCursorTo(cursorCoords)

  # Open document and move cursor to positon
  moveCursorTo: (cursorCoords) ->
    lineNumber = parseInt(cursorCoords[0])
    charNumber = parseInt(cursorCoords[1])

    if textEditor = atom.workspace.getActiveTextEditor()
      position = [lineNumber, charNumber]
      textEditor.setCursorBufferPosition(position, autoscroll: false)
      textEditor.scrollToCursorPosition(center: true)
