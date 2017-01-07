{CompositeDisposable, TextBuffer} = require 'atom'
{ScrollView, TextEditorView} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'

TodoTable = require './todo-table-view'
TodoOptions = require './todo-options-view'

deprecatedTextEditor = (params) ->
  if atom.workspace.buildTextEditor?
    atom.workspace.buildTextEditor(params)
  else
    TextEditor = require('atom').TextEditor
    new TextEditor(params)

module.exports =
class ShowTodoView extends ScrollView
  @content: (collection, filterBuffer) ->
    filterEditor = deprecatedTextEditor(
      mini: true
      tabLength: 2
      softTabs: true
      softWrapped: false
      buffer: filterBuffer
      placeholderText: 'Search Todos'
    )

    @div class: 'show-todo-preview', tabindex: -1, =>
      @div class: 'input-block', =>
        @div class: 'input-block-item input-block-item--flex', =>
          @subview 'filterEditorView', new TextEditorView(editor: filterEditor)
        @div class: 'input-block-item', =>
          @div class: 'btn-group', =>
            @button outlet: 'scopeButton', class: 'btn'
            @button outlet: 'optionsButton', class: 'btn icon-gear'
            @button outlet: 'saveAsButton', class: 'btn icon-cloud-download'
            @button outlet: 'refreshButton', class: 'btn icon-sync'

      @div class: 'input-block todo-info-block', =>
        @div class: 'input-block-item', =>
          @span outlet: 'todoInfo'

      @div outlet: 'optionsView'

      @div outlet: 'todoLoading', class: 'todo-loading', =>
        @div class: 'markdown-spinner'
        @h5 outlet: 'searchCount', class: 'text-center', "Loading Todos..."

      @subview 'todoTable', new TodoTable(collection)

  constructor: (@collection, @uri) ->
    super @collection, @filterBuffer = new TextBuffer

  initialize: ->
    @disposables = new CompositeDisposable
    @handleEvents()
    @collection.search()
    @setScopeButtonState(@collection.getSearchScope())

    @notificationOptions =
      detail: 'Atom todo-show package'
      dismissable: true
      icon: @getIconName()

    @checkDeprecation()

    @disposables.add atom.tooltips.add @scopeButton, title: "What to Search"
    @disposables.add atom.tooltips.add @optionsButton, title: "Show Todo Options"
    @disposables.add atom.tooltips.add @saveAsButton, title: "Save Todos to File"
    @disposables.add atom.tooltips.add @refreshButton, title: "Refresh Todos"

  handleEvents: ->
    @disposables.add atom.commands.add @element,
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:refresh': (event) =>
        event.stopPropagation()
        @collection.search()

    # Persist pane size by saving to local storage
    pane = atom.workspace.getActivePane()
    @restorePaneFlex(pane) if atom.config.get('todo-show.rememberViewSize')
    @disposables.add pane.observeFlexScale (flexScale) =>
      @savePaneFlex(flexScale)

    @disposables.add @collection.onDidStartSearch @startLoading
    @disposables.add @collection.onDidFinishSearch @stopLoading
    @disposables.add @collection.onDidFailSearch (err) =>
      @searchCount.text "Search Failed"
      console.error err if err
      @showError err if err

    @disposables.add @collection.onDidChangeSearchScope (scope) =>
      @setScopeButtonState(scope)
      @collection.search()

    @disposables.add @collection.onDidSearchPaths (nPaths) =>
      @searchCount.text "#{nPaths} paths searched..."

    @disposables.add atom.workspace.onDidChangeActivePaneItem (item) =>
      if @collection.setActiveProject(item?.getPath?()) or
      (item?.constructor.name is 'TextEditor' and @collection.scope is 'active')
        @collection.search()

    @disposables.add atom.workspace.onDidAddTextEditor ({textEditor}) =>
      @collection.search() if @collection.scope is 'open'

    @disposables.add atom.workspace.onDidDestroyPaneItem ({item}) =>
      @collection.search() if @collection.scope is 'open'

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.onDidSave => @collection.search()

    @filterEditorView.getModel().onDidStopChanging =>
      @filter() if @firstTimeFilter
      @firstTimeFilter = true

    @scopeButton.on 'click', @toggleSearchScope
    @optionsButton.on 'click', @toggleOptions
    @saveAsButton.on 'click', @saveAs
    @refreshButton.on 'click', => @collection.search()

  destroy: ->
    @collection.cancelSearch()
    @disposables.dispose()
    @detach()

  savePaneFlex: (flex) ->
    localStorage.setItem 'todo-show.flex', flex

  restorePaneFlex: (pane) ->
    flex = localStorage.getItem 'todo-show.flex'
    pane.setFlexScale parseFloat(flex) if flex

  getTitle: -> "Todo Show"
  getIconName: -> "checklist"
  getURI: -> @uri
  getProjectName: -> @collection.getActiveProjectName()
  getProjectPath: -> @collection.getActiveProject()
  getTodos: -> @collection.getTodos()
  getTodosCount: -> @collection.getTodosCount()
  isSearching: -> @collection.getState()

  startLoading: =>
    @todoLoading.show()
    @updateInfo()

  stopLoading: =>
    @todoLoading.hide()
    @updateInfo()

  updateInfo: ->
    @todoInfo.html("#{@getInfoText()} #{@getScopeText()}")

  getInfoText: ->
    return "Found ... results" if @isSearching()
    switch count = @getTodosCount()
      when 1 then "Found #{count} result"
      else "Found #{count} results"

  getScopeText: ->
    # TODO: Also show number of files

    switch @collection.scope
      when 'active'
        "in active file"
      when 'open'
        "in open files"
      when 'project'
        "in project <code>#{@getProjectName()}</code>"
      else
        "in workspace"

  showError: (message = '') ->
    atom.notifications.addError message.toString(), @notificationOptions

  showWarning: (message = '') ->
    atom.notifications.addWarning message.toString(), @notificationOptions

  saveAs: =>
    return if @isSearching()

    filePath = "#{@getProjectName() or 'todos'}.md"
    if projectPath = @getProjectPath()
      filePath = path.join(projectPath, filePath)

    if outputFilePath = atom.showSaveDialogSync(filePath.toLowerCase())
      fs.writeFileSync(outputFilePath, @collection.getMarkdown())
      atom.workspace.open(outputFilePath)

  toggleSearchScope: =>
    scope = @collection.toggleSearchScope()
    @setScopeButtonState(scope)

  setScopeButtonState: (state) =>
    switch state
      when 'workspace' then @scopeButton.text 'Workspace'
      when 'project' then @scopeButton.text 'Project'
      when 'open' then @scopeButton.text 'Open Files'
      when 'active' then @scopeButton.text 'Active File'

  toggleOptions: =>
    unless @todoOptions
      @optionsView.hide()
      @todoOptions = new TodoOptions(@collection)
      @optionsView.html @todoOptions
    @optionsView.slideToggle()

  filter: ->
    @collection.filterTodos @filterBuffer.getText()

  checkDeprecation: ->
    if atom.config.get('todo-show.findTheseRegexes')
      @showWarning '''
      Deprecation Warning:\n
      `findTheseRegexes` config is deprecated, please use `findTheseTodos` and `findUsingRegex` for custom behaviour.
      See https://github.com/mrodalgaard/atom-todo-show#config for more information.
      '''
