{CompositeDisposable, TextBuffer} = require 'atom'
{ScrollView, TextEditorView} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'

TodoTable = require './todo-table-view'
TodoOptions = require './todo-options-view'

module.exports =
class ShowTodoView extends ScrollView
  @content: (collection, filterBuffer) ->
    filterEditor = atom.workspace.buildTextEditor(
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

    @disposables.add @collection.onDidChangeSearchScope @setScopeButtonState
    @disposables.add @collection.onDidStartSearch @startLoading
    @disposables.add @collection.onDidFinishSearch @stopLoading
    @disposables.add @collection.onDidFailSearch (err) =>
      @searchCount.text "Search Failed"
      console.error err if err
      @showError err if err

    @disposables.add @collection.onDidSearchPaths (nPaths) =>
      @searchCount.text "#{nPaths} paths searched..."

    @disposables.add atom.workspace.onDidChangeActivePaneItem (item) =>
      if item?.constructor.name is 'TextEditor' and @collection.scope is 'active'
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

  getTitle: ->
    return "Todo Show: ..." if @loading
    switch count = @collection.getTodosCount()
      when 1 then "Todo Show: #{count} result"
      else "Todo Show: #{count} results"

  getIconName: ->
    "checklist"

  getURI: ->
    @uri

  getProjectPath: ->
    atom.project.getPaths()[0]

  getProjectName: ->
    atom.project.getDirectories()[0]?.getBaseName()

  startLoading: =>
    @loading = true
    @todoLoading.show()
    @updateTabTitle()

  stopLoading: =>
    @loading = false
    @todoLoading.hide()
    @updateTabTitle()

  updateTabTitle: ->
    view = atom.views.getView(@)
    return unless view and view.parentElement?.parentElement
    for tab in view.parentElement.parentElement.querySelectorAll('.tab')
      tab.updateTitle?()

  getTodos: ->
    @collection.getTodos()

  showError: (message = '') ->
    atom.notifications.addError message, @notificationOptions

  showWarning: (message = '') ->
    atom.notifications.addWarning message, @notificationOptions

  saveAs: =>
    return if @collection.isSearching()

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
      when 'full' then @scopeButton.text 'Workspace'
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
