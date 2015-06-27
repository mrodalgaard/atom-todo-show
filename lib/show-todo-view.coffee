{CompositeDisposable} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'

Q = require 'q'
slash = require 'slash'
ignore = require 'ignore'

TodoItemView = require './todo-item-view'
TodoEmptyView = require './todo-empty-view'

module.exports =
class ShowTodoView extends ScrollView
  maxLength: 120

  @content: ->
    @div class: 'show-todo-preview native-key-bindings', tabindex: -1, =>
      @div class: 'todo-action-items pull-right', =>
        @a outlet: 'saveAsButton', class: 'icon icon-cloud-download'
        @a outlet: 'refreshButton', class: 'icon icon-sync'

      @div outlet: 'todoLoading', =>
        @div class: 'markdown-spinner'
        @h5 outlet: 'searchCount', class: 'text-center', "Loading Todos..."

      @div outlet: 'todoList'

  constructor: ({@filePath}) ->
    super
    @disposables = new CompositeDisposable
    @handleEvents()

    # Determine if you are searching full workspace or just open files
    @searchWorkspace = @filePath isnt '/Open-TODOs'

  handleEvents: ->
    @disposables.add atom.commands.add @element,
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:refresh': (event) =>
        event.stopPropagation()
        @renderTodos()

    @saveAsButton.on 'click', => @saveAs()
    @refreshButton.on 'click', => @renderTodos()

  destroy: ->
    @cancelScan()
    @detach()
    @disposables?.dispose()

  getTitle: ->
    if @searchWorkspace then "Todo-Show Results" else "Todo-Show Open Files"

  getURI: ->
    "todolist-preview:///#{@getPath()}"

  getPath: ->
    @filePath

  getProjectPath: ->
    atom.project.getPaths()[0]

  startLoading: ->
    @loading = true
    @todoList.empty()
    @todoLoading.show()

  stopLoading: ->
    @loading = false
    @todoLoading.hide()

  # Get regexes to look for from settings
  buildRegexLookups: (settingsRegexes) ->
    for regex, i in settingsRegexes by 2
      'title': regex
      'regex': settingsRegexes[i+1]
      'results': []

  # Pass in string and returns a proper RegExp object
  makeRegexObj: (regexStr) ->
    # Extract the regex pattern (anything between the slashes)
    pattern = regexStr.match(/\/(.+)\//)?[1]
    # Extract the flags (after last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1]

    return false unless pattern
    new RegExp(pattern, flags)

  # Parses and strips result from scan
  handleScanResult: (result, regex) ->
    # Loop through the scan results
    for match in result.matches
      matchText = match.matchText

      # Strip out the regex token from the found annotation
      # not all objects will have an exec match
      while (_match = regex?.exec(matchText))
        matchText = _match.pop()

      # Strip common block comment endings and whitespaces
      matchText = matchText.replace(/(\*\/|-->|#>|-}|\]\])\s*$/, '').trim()

      # Truncate long match strings
      if matchText.length >= @maxLength
        matchText = "#{matchText.substring(0, @maxLength - 3)}..."

      match.matchText = matchText

      # Make sure range is serialized to produce correct rendered format
      # See https://github.com/jamischarles/atom-todo-show/issues/27
      if match.range.serialize
        match.rangeString = match.range.serialize().toString()
      else
        match.rangeString = match.range.toString()

    result.relativePath = atom.project.relativize(result.filePath)
    return result

  # Scan project workspace for the lookup that is passed
  # returns a promise that the scan generates
  fetchRegexItem: (regexLookup) ->
    regex = @makeRegexObj(regexLookup.regex)
    return false unless regex

    # Handle ignores from settings
    ignoresFromSettings = atom.config.get('todo-show.ignoreThesePaths')
    hasIgnores = ignoresFromSettings?.length > 0
    ignoreRules = ignore({ ignore:ignoresFromSettings })

    # TODO: Use paths option as ignoreRules by adding them as an array
    # of exclusions (!) after atom fix: https://github.com/atom/atom/pull/6386
    # otherwise use full pattern; e.g. `!*/node_modules/**/*.*`
    # This would hopefully also remove dependency on slash and ignore, while
    # using default node-minimatch.

    # Only track progress on first scan
    options = {}
    if !@firstRegex
      @firstRegex = true
      onPathsSearched = (nPaths) =>
        @searchCount.text("#{nPaths} paths searched...") if @loading
      options = {paths: '*', onPathsSearched}

    atom.workspace.scan regex, options, (result, error) =>
      console.debug error.message if error

      if result
        # Check against ignored paths
        pathToTest = slash(result.filePath.substring(atom.project.getPaths()[0].length))
        return if (hasIgnores && ignoreRules.filter([pathToTest]).length == 0)

        regexLookup.results.push @handleScanResult(result, regex)

  # Scan open files for the lookup that is passed
  fetchOpenRegexItem: (regexLookup) ->
    regex = @makeRegexObj(regexLookup.regex)
    return false unless regex

    deferred = Q.defer()

    for editor in atom.workspace.getTextEditors()
      # Use same object layout as workspace scan with single match
      result =
        filePath: editor.getPath()
        matches: []

      editor.scan regex, (scanResult, error) ->
        console.debug error.message if error

        if scanResult
          result.matches.push
            matchText: scanResult.matchText
            lineText: scanResult.matchText
            range: [
              [
                scanResult.computedRange.start.row
                scanResult.computedRange.start.column
              ]
              [
                scanResult.computedRange.end.row
                scanResult.computedRange.end.column
              ]
            ]

      if result.matches.length > 0
        regexLookup.results.push @handleScanResult(result, regex)

    # No async operations, so just return a resolved promise
    deferred.resolve()
    deferred.promise

  renderTodos: ->
    @startLoading()

    # Fetch the regexes from settings
    regexes = @buildRegexLookups(atom.config.get('todo-show.findTheseRegexes'))

    # Scan for each regex and get promises
    @searchPromises = []
    for regexObj in regexes
      if @searchWorkspace
        promise = @fetchRegexItem(regexObj)
      else
        promise = @fetchOpenRegexItem(regexObj)

      @searchPromises.push(promise)

    # Fire callback when ALL scans are done
    Q.all(@searchPromises).then () =>
      @stopLoading()

      # Remove empty regex matches
      @regexes = regexes.filter (regex) =>
        @todoList.append new TodoItemView(regex) if regex.results.length
        regex.results.length

      @todoList.append new TodoEmptyView unless @regexes.length

    return this

  cancelScan: ->
    for promise in @searchPromises
      promise.cancel() if promise

  getMarkdown: ->
    @regexes.map((regex) ->
      return unless regex.results.length

      out = "\n## #{regex.title}\n\n"

      for result in regex.results
        for match in result.matches
          out += "- #{match.matchText}"
          out += " `#{result.relativePath}:#{match.range[0][0] + 1}`\n"

      return out
    ).join('')

  saveAs: ->
    return if @loading

    filePath = "#{path.parse(@getPath()).name}.md"
    if @getProjectPath()
      filePath = path.join(@getProjectPath(), filePath)

    if outputFilePath = atom.showSaveDialogSync(filePath)
      fs.writeFileSync(outputFilePath, @getMarkdown())
      atom.workspace.open(outputFilePath)
