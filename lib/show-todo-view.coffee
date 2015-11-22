{CompositeDisposable} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'

TodoTable = require './show-todo-table-view'
TodoOptions = require './show-todo-options-view'

module.exports =
class ShowTodoView extends ScrollView
  maxLength: 120

  @content: (@model) ->
    @div class: 'show-todo-preview native-key-bindings', tabindex: -1, =>
      @div class: 'text-right', =>
        @div class: 'btn-group', =>
          @button outlet: 'scopeButton', class: 'btn'
          @button outlet: 'optionsButton', class: 'btn icon-gear'
          # @button outlet: 'saveAsButton', class: 'btn icon-cloud-download'
          @button outlet: 'refreshButton', class: 'btn icon-sync'

      @div outlet: 'optionsView'

      @div outlet: 'todoLoading', =>
        @div class: 'markdown-spinner'
        @h5 outlet: 'searchCount', class: 'text-center', "Loading Todos..."

      @subview 'todoTable', new TodoTable(@model)

  initialize: (@model, @searchWorkspace = true) ->
    @disposables = new CompositeDisposable
    @handleEvents()
    @model.search()
    @setScopeButtonState(@model.getSearchScope())

    @disposables.add atom.tooltips.add @scopeButton, title: "What to Search"
    @disposables.add atom.tooltips.add @optionsButton, title: "Show Todo Options"
    # @disposables.add atom.tooltips.add @saveAsButton, title: "Save Todos to File"
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

    @scopeButton.on 'click', @toggleSearchScope
    @optionsButton.on 'click', @toggleOptions
    # @saveAsButton.on 'click', @saveAs
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
    if @searchWorkspace then "Todo-Show Results" else "Todo-Show Open Files"

  getIconName: ->
    "checklist"

  getURI: ->
    if @searchWorkspace then @constructor.URI else @constructor.URIopen

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

  showError: (message) ->
    atom.notifications.addError 'todo-show', detail: message, dismissable: true

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

  # TODO: "Save as" is broken
  saveAs: =>
    return if @model.isSearching()

    filePath = "#{@getProjectName() or 'todos'}.md"
    if projectPath = @getProjectPath()
      filePath = path.join(projectPath, filePath)

    if outputFilePath = atom.showSaveDialogSync(filePath.toLowerCase())
      fs.writeFileSync(outputFilePath, @getMarkdown(@matches))
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
    @optionsView.toggle()
