# This file handles all the fetching and displaying logic. It doesn't handle any of the pane magic.
# Pane magic happens in show-todo.coffee.
# Markup is in template/show-todo-template.html
# Styling is in the stylesheets folder.

path = require 'path'
fs = require 'fs-plus'
{Emitter, Disposable, CompositeDisposable, Point} = require 'atom'
{$$$, ScrollView} = require 'atom-space-pen-views'

Q = require 'q'
slash = require 'slash'
ignore = require 'ignore'

module.exports =
class ShowTodoView extends ScrollView
  @content: ->
    @div class: 'show-todo-preview native-key-bindings', tabindex: -1

  constructor: ({@filePath}) ->
    super
    @handleEvents()
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  destroy: ->
    @detach()
    @disposables.dispose()

  getTitle: ->
    "Todo-Show Results"

  getURI: ->
    "todolist-preview://#{@getPath()}"

  getPath: ->
    "TODOs"
  
  getProjectPath: ->
    atom.project.getPaths()[0]

  onDidChangeTitle: -> new Disposable()
  onDidChangeModified: -> new Disposable()

  showLoading: ->
    @loading = true
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Todos...'
  
  showTodos: (regexes) ->
    @html $$$ ->
      @div class: 'todo-action-items pull-right', =>
        @a class: 'todo-save-as', =>
          @span class: 'icon icon-cloud-download'
        @a class: 'todo-refresh', =>
          @span class: 'icon icon-sync'
      
      for regex in regexes
        @section =>
          @h1 =>
            @span regex.title + ' '
            @span class: 'regex', regex.regex
          @table =>
            for result in regex.results
              for match in result.matches
                @tr =>
                  @td match.matchText
                  @td =>
                    filePath = atom.project.relativize(result.filePath)
                    @a class: 'todo-url', 'data-uri': filePath, 'data-coords': match.range, filePath
                    
    @loading = false

  # Get regexes to look for from settings
  buildRegexLookups: (settingsRegexes) ->
    for regex, i in settingsRegexes by 2
      'title': regex
      'regex': settingsRegexes[i+1]
      'results': []

  # Pass in string and returns a proper RegExp object
  makeRegexObj: (regexStr) ->
    # extract the regex pattern
    pattern = regexStr.match(/\/(.+)\//)?[1] #extract anything between the slashes
    # extract the flags (after the last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1] #extract any words after the last slash. Flags are optional

    # abort if there's no valid pattern
    return false unless pattern

    return new RegExp(pattern, flags)

  # Scan the project for the regex that is passed
  # returns a promise that the project scan generates
  # @TODO: Improve the param name. Confusing
  fetchRegexItem: (lookupObj) ->
    regexObj = @makeRegexObj(lookupObj.regex)

    # abort if there's no valid pattern
    return false unless regexObj

    # handle ignores from settings
    ignoresFromSettings = atom.config.get('todo-show.ignoreThesePaths')
    hasIgnores = ignoresFromSettings?.length > 0
    ignoreRules = ignore({ ignore:ignoresFromSettings })
    
    return atom.workspace.scan regexObj, (e) ->
      # check against ignored paths
      include = true
      pathToTest = slash(e.filePath.substring(atom.project.getPaths()[0].length))
      if (hasIgnores && ignoreRules.filter([pathToTest]).length == 0)
        include = false
        
      if include
        # loop through the results in the file, strip out 'todo:', and allow an optional space after todo:
        # regExMatch.matchText = regExMatch.matchText.match(regexObj)[1] for regExMatch in e.matches
        for regExMatch in e.matches
          # strip out the regex token from the found phrase (todo, fixme, etc)
          # FIXME: I have no idea why this requires a stupid while loop. Figure it out and/or fix it.
          while (match = regexObj.exec(regExMatch.matchText))
            regExMatch.matchText = match[1].trim()
        
        # FIXME: fix the sort order of results
        lookupObj.results.push(e)

  renderTodos: ->
    @showLoading()

    # fetch the reges from the settings
    regexes = @buildRegexLookups(atom.config.get('todo-show.findTheseRegexes'))

    # @FIXME: abstract this into a separate, testable function?
    promises = []
    for regexObj in regexes
      # scan the project for each regex, and get a promise in return
      promise = @fetchRegexItem(regexObj)
      promises.push(promise) # create array of promises so we can listen for completion

    # fire callback when ALL project scans are done
    Q.all(promises).then () =>
      @showTodos(@regexes = regexes)

  handleEvents: ->
    atom.commands.add @element,
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:refresh': (event) =>
        event.stopPropagation()
        @renderTodos()
    
    @on 'click', '.todo-url',  (e) =>
      link = e.target
      @openPath(link.dataset.uri, link.dataset.coords.split(','))
    @on 'click', '.todo-save-as', =>
      @saveAs()
    @on 'click', '.todo-refresh', =>
      @renderTodos()

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
  
  getMarkdown: ->
    @regexes.map((regex) ->
      return unless regex.results.length
      
      out = '\n## ' + regex.title + '\n\n'
      
      regex.results?.map((result) ->
        result.matches?.map((match) ->
          out += '- ' + match.matchText
          out += ' _(' + atom.project.relativize(result.filePath) + ')_\n'
        )
      )
      out
    ).join("")
  
  saveAs: ->
    return if @loading
    
    filePath = path.parse(@getPath()).name + '.txt'
    if @getProjectPath()
      filePath = path.join(@getProjectPath(), filePath)

    if outputFilePath = atom.showSaveDialogSync(filePath)
      fs.writeFileSync(outputFilePath, @getMarkdown())
      atom.workspace.open(outputFilePath)
