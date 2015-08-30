{CompositeDisposable} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'
_ = require 'underscore-plus'

Q = require 'q'
slash = require 'slash'
ignore = require 'ignore'

{TodoRegexView, TodoFileView, TodoNoneView, TodoEmptyView} = require './todo-item-view'

module.exports =
class ShowTodoView extends ScrollView
  maxLength: 120
  matches: []

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
        @getTodos()

    # Persist pane size by saving to local storage
    pane = atom.workspace.getActivePane()
    @restorePaneFlex(pane) if atom.config.get('todo-show.rememberViewSize')
    @disposables.add pane.observeFlexScale (flexScale) =>
      @savePaneFlex(flexScale)

    @saveAsButton.on 'click', => @saveAs()
    @refreshButton.on 'click', => @getTodos()

  destroy: ->
    @cancelScan()
    @disposables?.dispose()
    @detach()

  savePaneFlex: (flex) ->
    localStorage.setItem 'todo-show.flex', flex

  restorePaneFlex: (pane) ->
    flex = localStorage.getItem 'todo-show.flex'
    pane.setFlexScale parseFloat(flex) if flex

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
    @matches = []
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

  # Pass in string and returns a proper RegExp object
  makeRegexObj: (regexStr) ->
    # Extract the regex pattern (anything between the slashes)
    pattern = regexStr.match(/\/(.+)\//)?[1]
    # Extract the flags (after last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1]

    return false unless pattern
    new RegExp(pattern, flags)

  handleScanMatch: (match, regex) ->
    matchText = match.matchText

    # Strip out the regex token from the found annotation
    # not all objects will have an exec match
    while (_match = regex?.exec(matchText))
      matchText = _match.pop()

    # Strip common block comment endings and whitespaces
    matchText = matchText.replace(/(\*\/|\?>|-->|#>|-}|\]\])\s*$/, '').trim()

    # Truncate long match strings
    if matchText.length >= @maxLength
      matchText = "#{matchText.substring(0, @maxLength - 3)}..."

    match.matchText = matchText || 'No details'

    # Make sure range is serialized to produce correct rendered format
    # See https://github.com/jamischarles/atom-todo-show/issues/27
    if match.range.serialize
      match.rangeString = match.range.serialize().toString()
    else
      match.rangeString = match.range.toString()

    match.relativePath = atom.project.relativize(match.path)
    return match

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
      return unless result

      # Check against ignored paths
      pathToTest = slash(result.filePath.substring(atom.project.getPaths()[0].length))
      return if (hasIgnores && ignoreRules.filter([pathToTest]).length == 0)

      for match in result.matches
        match.title = regexLookup.title
        match.regex = regexLookup.regex
        match.path = result.filePath
        @matches.push @handleScanMatch(match, regex)

  # Scan open files for the lookup that is passed
  fetchOpenRegexItem: (regexLookup) ->
    regex = @makeRegexObj(regexLookup.regex)
    return false unless regex

    deferred = Q.defer()

    for editor in atom.workspace.getTextEditors()
      editor.scan regex, (result, error) =>
        console.debug error.message if error
        return unless result

        match =
          title: regexLookup.title
          regex: regexLookup.regex
          path: editor.getPath()
          matchText: result.matchText
          lineText: result.matchText
          range: [
            [
              result.computedRange.start.row
              result.computedRange.start.column
            ]
            [
              result.computedRange.end.row
              result.computedRange.end.column
            ]
          ]
        @matches.push @handleScanMatch(match, regex)

    # No async operations, so just return a resolved promise
    deferred.resolve()
    deferred.promise

  getTodos: ->
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
      @renderTodos @matches

    return this

  groupMatches: (matches, cb) ->
    regexes = atom.config.get('todo-show.findTheseRegexes')
    groupBy = atom.config.get('todo-show.groupMatchesBy')

    switch groupBy
      when 'file'
        iteratee = 'relativePath'
        sortedMatches = _.sortBy(matches, iteratee)
      when 'none'
        sortedMatches = _.sortBy(matches, 'matchText')
        return cb(sortedMatches, groupBy)
      else
        iteratee = 'title'
        sortedMatches = _.sortBy(matches, (match) ->
          regexes.indexOf(match[iteratee])
        )

    for own key, group of _.groupBy(sortedMatches, iteratee)
      cb(group, groupBy)

  renderTodos: (matches) ->
    unless matches.length
      return @todoList.append new TodoEmptyView

    @groupMatches(matches, (group, groupBy) =>
      switch groupBy
        when 'file'
          @todoList.append new TodoFileView(group)
        when 'none'
          @todoList.append new TodoNoneView(group)
        else
          @todoList.append new TodoRegexView(group)
    )

  cancelScan: ->
    for promise in @searchPromises
      promise.cancel() if promise

  getMarkdown: (matches) ->
    markdown = []
    @groupMatches(matches, (group, groupBy) ->
      switch groupBy
        when 'file'
          out = "\n## #{group[0].relativePath || 'Unknown File'}\n\n"
          for match in group
            out += "- #{match.matchText || 'empty'}"
            out += " `#{match.title}`" if match.title
            out += "\n"

        when 'none'
          out = "\n## All Matches\n\n"
          for match in group
            out += "- #{match.matchText || 'empty'}"
            out += " _(#{match.title})_" if match.title
            out += " `#{match.relativePath}`" if match.relativePath
            out += " `:#{match.range[0][0] + 1}`" if match.range and match.range[0]
            out += "\n"

        else
          out = "\n## #{group[0].title || 'No Title'}\n\n"
          for match in group
            out += "- #{match.matchText || 'empty'}"
            out += " `#{match.relativePath}`" if match.relativePath
            out += " `:#{match.range[0][0] + 1}`" if match.range and match.range[0]
            out += "\n"
      markdown.push out
    )
    markdown.join('')

  saveAs: ->
    return if @loading

    filePath = "#{path.parse(@getPath()).name}.md"
    if @getProjectPath()
      filePath = path.join(@getProjectPath(), filePath)

    if outputFilePath = atom.showSaveDialogSync(filePath.toLowerCase())
      fs.writeFileSync(outputFilePath, @getMarkdown(@matches))
      atom.workspace.open(outputFilePath)
