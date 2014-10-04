# This file handles all the fetching and displaying logic. It doesn't handle any of the pane magic.
# Pane magic happens in show-todo.coffee.
# Markup is in template/show-todo-template.html
# Styling is in the stylesheets folder.
#
# FIXME: Realizing this is some pretty nasty code. This should really, REALLY be cleaned up. Testing should help.
# Also, having a greater understanding of Atom should help.

vm = require 'vm'  #needed for the Content Security Policy errors when executing JS from my template view
Q = require 'q'
path = require 'path'
{$, $$$, Point, EditorView, ScrollView} = require 'atom'
{allowUnsafeEval, allowUnsafeNewFunction} = require 'loophole' #needed for the Content Security Policy errors when executing JS from my template view
# {File} = require 'pathwatcher'
fs = require 'fs-plus'
_ = require 'underscore'


module.exports =
class ShowTodoView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: ({filePath}) ->
    new ShowTodoView(filePath)

  constructor: (filePath) ->
    super
    # @file = new File(filePath)
    @handleEvents()

  @content: ->
    @div class: 'show-todo-preview native-key-bindings', tabindex: -1


  initialize: (serializeState) ->
    # atom.workspaceView.command "show-todo:toggle", => @toggle()
    # Add the view click handler that goes to the marker (todo, fixme, whatnot)
    this.on 'click', '.file_url a',  (e) => # handle click here
      link = e.target
      @openPath(link.dataset.uri, link.dataset.coords.split(','));

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  getTitle: ->
    "Todo-show Results" #just put this title in there

  getUri: ->
    "todolist-preview://#{@getPath()}"

  getPath: ->
    # @file.getPath()

  resolveImagePaths: (html) =>
    html = $(html)
    imgList = html.find("img")

    for imgElement in imgList
      img = $(imgElement)
      src = img.attr('src')
      continue if src.match /^(https?:\/\/)/
      img.attr('src', path.resolve(path.dirname(@getPath()), src))

    html

  # currently broken. FIXME: Remove or replace
  resolveJSPaths: (html) =>
    # console.log('INISDE RESOLVE')
    html = $(html)


    # scrList = html.find("#mainScript")
    scrList = [html[5]]

    # console.log('html', html)
    # console.log('hi')
    # console.log('srcList', scrList)

    for scrElement in scrList
      js = $(scrElement)
      src = js.attr('src')
      # continue if src.match /^(https?:\/\/)/
      js.attr('src', path.resolve(path.dirname(@getPath()), src))
      # console.log 'js', js
    html

  showLoading: ->
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Todos...'




  #get the regexes to look for from the settings
  # @FIXME: Add proper comments
  # @param settingsRegexes {array} - An array of regexes from settings.
  buildRegexLookups: (settingsRegexes) ->
    regexes = [] #[{title, regex, results}]

    for regex, i in settingsRegexes
      match = {
        'title': regex
        'regex': settingsRegexes[i+1]
        'results': []
      }
      _i = _i+1    #_ overrides the one that coffeescript actually creates. Seems hackish. FIXME: maybe just use modulus
      regexes.push(match)

    return regexes

  # Pass in '/FIXME:(.+$)/g ' and returns a proper RegExp obj
  makeRegexObj: (regexStr) ->
    # extract the regex pattern
    pattern = regexStr.match(/\/(.+)\//)?[1] #extract anything between the slashes
    # extract the flags (after the last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1] #extract any words after the last slash. Flags are optional

    #abort if there's no valid pattern
    return false unless pattern

    return new RegExp(pattern, flags)

  #@TODO: Actually figure out how promises work.
  # scan the project for the regex that is passed
  # returns a promise that the project scan generates
  # @TODO: Improve the param name. Confusing
  fetchRegexItem: (lookupObj) ->
    regexObj = @makeRegexObj(lookupObj.regex)

    #abort if there's no valid pattern
    return false unless regexObj

    # console.log('pattern', pattern)
    # console.log('regexObj', regexObj)
    return atom.project.scan regexObj, (e) ->
      # Check against ignored paths
      include = true
      ignoreFromSettings = atom.config.get('todo-show.ignoreThesePaths')

      for ignorePath in ignoreFromSettings
        ignoredPath = atom.project.getPath() + ignorePath

        if e.filePath.substring(0, ignoredPath.length) == ignoredPath
          include = false

      if include
        # loop through the results in the file, strip out 'todo:', and allow an optional space after todo:
        # regExMatch.matchText = regExMatch.matchText.match(regexObj)[1] for regExMatch in e.matches
        for regExMatch in e.matches
          # strip out the regex token from the found phrase (todo, fixme, etc)
          # FIXME: I have no idea why this requires a stupid while loop. Figure it out and/or fix it.
          while (match = regexObj.exec(regExMatch.matchText))
            regExMatch.matchText = match[1]

        lookupObj.results.push(e) # add it to the array of results for this regex

  renderTodos: ->
    @showLoading()

    #fetch the reges from the settings
    regexes = @buildRegexLookups(atom.config.get('todo-show.findTheseRegexes'))

    #@FIXME: abstract this into a separate, testable function?
    promises = []
    for regexObj in regexes
      #scan the project for each regex, and get a promise in return
      promise = @fetchRegexItem(regexObj)  #inspect -> {state: 'pending'}
      promises.push(promise) #create array of promises so we can listen for completion


    # fire callback when ALL project scans are done
    Q.all(promises).then () =>

      # wasn't able to load 'dust' properly for some reason
      dust = require('dust.js') #templating engine

      # template = hogan.compile("Hello {name}!");

      # team = ['jamis', 'adam', 'johnson']

      # load up the template
      # path.resolve __dirname, '../template/show-todo-template.html'
      templ_path = path.resolve(__dirname, '../template/show-todo-template.html')
      if ( fs.isFileSync(templ_path) )
        template = fs.readFileSync(templ_path, {encoding: "utf8"})

      #FIXME: Add better error handling if the template fails to load
      compiled = dust.compile(template, "todo-template")

      #is this step necessary? Appears to be...
      dust.loadSource(compiled)

      # content & filters
      context = {
        #make the path to the result relative
        "filterPath": (chunk, context, bodies) =>
          return chunk.tap((data) =>

            # make it relative
            return atom.project.relativize(data);
          ).render(bodies.block, context).untap();
        ,
        "results": regexes #FIXME: fix the sort order in the results
        # "todo_items": todoArray,
        # "fixme_items": fixmeArray,
        # "changed_items": changedArray,
        # "todo_items_length": todo_total_length,
        # "fixme_items_length": fixme_total_length,
        # "changed_items_length": changed_total_length
      }

      # console.log('VM', vm);
      # vm.evalInThisContext(console.log('hi something in vm'));

      # render the template
      # doSomething: ->

      dust.render "todo-template", context, (err, out) =>
        # console.log 'err', err
        # console.log('content to be rendered', out);
        # allowUnsafeEval  ->
        # console.log('hi ho')
        # out = @resolveJSPaths out #resolve the relative JS paths for external <script> in view
        @html(out)
        # @html 'hi'

      # vm.evalInThisContext("doSomething()");


  # events that handle showing of todos
  handleEvents: ->
    @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderTodos()), 250)
    @subscribe this, 'core:move-up', => @scrollUp()
    @subscribe this, 'core:move-down', => @scrollDown()
    # fixME: probably not necessary. Can Likely be removed.
    # @subscribe @file, 'contents-changed', =>
    #   @renderTodos()
    #   pane = atom.workspace.paneForUri(@getUri())
    #   if pane? and pane isnt atom.workspace.getActivePane()
    #     pane.activateItem(this)


  # open a new window, and load the file that we need.
  # we call this from the results view. This will open the result file in the left pane.
  openPath: (filePath, cursorCoords) ->
    return unless filePath

    #if there's no workspace, create a workspace... Doesn't appear to be necessary?
    # console.log('workspace', atom.workspace)

    atom.workspaceView.open(filePath, split: 'left', {@allowActiveEditorChange}).done =>
      @moveCursorTo(cursorCoords)

  # taken directly from atom/fuzzy-finder
  moveCursorTo: (cursorCoords) ->
    lineNumber = parseInt(cursorCoords[0]) #take the regex start char [0], [1]
    charNumber = parseInt(cursorCoords[1])
    # return unless lineNumber >= 0

    if editorView = atom.workspaceView.getActiveView()
      position = [lineNumber, charNumber]
      editorView.scrollToBufferPosition(position, center: true)
      editorView.editor.setCursorBufferPosition(position)
      # editorView.editor.moveCursorToFirstCharacterOfLine()

  # toggle: ->
  #   @renderTodos()
  #   console.log "ShowTodoView was toggled!"
    # if @hasParent()
    #   @detach()
    # else
    #   atom.workspaceView.append(this)
