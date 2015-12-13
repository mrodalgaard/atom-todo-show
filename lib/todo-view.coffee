{CompositeDisposable, TextBuffer} = require 'atom'
{ScrollView, TextEditorView} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'

TodoTable = require './show-todo-table-view'
TodoOptions = require './show-todo-options-view'

module.exports =
class ShowTodoView extends ScrollView
  @content: (model, filterBuffer) ->
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

      @subview 'todoTable', new TodoTable(model)

  constructor: (@model, @uri) ->
    super @model, @filterBuffer = new TextBuffer

  initialize: ->
    @disposables = new CompositeDisposable
    @handleEvents()
    @model.search()
    @setScopeButtonState(@model.getSearchScope())

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
        @model.search()

    # Persist pane size by saving to local storage
    pane = atom.workspace.getActivePane()
    @restorePaneFlex(pane) if atom.config.get('todo-show.rememberViewSize')
    @disposables.add pane.observeFlexScale (flexScale) =>
      @savePaneFlex(flexScale)

    @disposables.add @model.onDidChangeSearchScope @setScopeButtonState
    @disposables.add @model.onDidStartSearch @startLoading
    @disposables.add @model.onDidFinishSearch @stopLoading
    @disposables.add @model.onDidFailSearch (err) =>
      @searchCount.text "Search Failed"
      console.error err if err
      @showError err if err

    @disposables.add @model.onDidSearchPaths (nPaths) =>
      @searchCount.text "#{nPaths} paths searched..."

    @disposables.add atom.workspace.onDidChangeActivePaneItem (item) =>
      if item?.constructor.name is 'TextEditor' and @model.scope is 'active'
        @model.search()

    @disposables.add atom.workspace.onDidAddTextEditor ({textEditor}) =>
      @model.search() if @model.scope is 'open'

    @disposables.add atom.workspace.onDidDestroyPaneItem ({item}) =>
      @model.search() if @model.scope is 'open'

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.onDidSave => @model.search()

    @filterEditorView.getModel().onDidStopChanging =>
      @filter() if @firstTimeFilter
      @firstTimeFilter = true

    @scopeButton.on 'click', @toggleSearchScope
    @optionsButton.on 'click', @toggleOptions
    @saveAsButton.on 'click', @saveAs
    @refreshButton.on 'click', => @model.search()

  destroy: ->
    @model.cancelSearch()
    @disposables.dispose()
    @detach()

  savePaneFlex: (flex) ->
    localStorage.setItem 'todo-show.flex', flex

  restorePaneFlex: (pane) ->
    flex = localStorage.getItem 'todo-show.flex'
    pane.setFlexScale parseFloat(flex) if flex

  getTitle: ->
    "Todo-Show Results"

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

  stopLoading: =>
    @loading = false
    @todoLoading.hide()

  getTodos: ->
    @model.getTodos()

  showError: (message) ->
    atom.notifications.addError 'todo-show', detail: message, dismissable: true

  saveAs: =>
    return if @model.isSearching()

    filePath = "#{@getProjectName() or 'todos'}.md"
    if projectPath = @getProjectPath()
      filePath = path.join(projectPath, filePath)

    if outputFilePath = atom.showSaveDialogSync(filePath.toLowerCase())
      fs.writeFileSync(outputFilePath, @model.getMarkdown())
      atom.workspace.open(outputFilePath)

  toggleSearchScope: =>
    scope = @model.toggleSearchScope()
    @setScopeButtonState(scope)

  setScopeButtonState: (state) =>
    switch state
      when 'full' then @scopeButton.text 'Workspace'
      when 'open' then @scopeButton.text 'Open Files'
      when 'active' then @scopeButton.text 'Active File'

  toggleOptions: =>
    unless @todoOptions
      @optionsView.hide()
      @todoOptions = new TodoOptions(@model)
      @optionsView.html @todoOptions
    @optionsView.slideToggle()

  filter: ->
    @model.filterTodos @filterBuffer.getText()
