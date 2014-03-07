path = require 'path'
{$, $$$, Point, EditorView, ScrollView} = require 'atom'
{File} = require 'pathwatcher'
fs = require 'fs-plus'
_ = require 'underscore'

todoArray = []
fixmeArray = []
changedArray = []


module.exports =
class ShowTodoView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: ({filePath}) ->
    new ShowTodoView(filePath)

  constructor: (filePath) ->
    super
    @file = new File(filePath)
    @handleEvents()

  @content: ->
    @div class: 'show-todo-preview native-key-bindings', tabindex: -1


  initialize: (serializeState) ->
    # atom.workspaceView.command "show-todo:toggle", => @toggle()



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
    @file.getPath()

  resolveImagePaths: (html) =>
    html = $(html)
    imgList = html.find("img")

    for imgElement in imgList
      img = $(imgElement)
      src = img.attr('src')
      continue if src.match /^(https?:\/\/)/
      img.attr('src', path.resolve(path.dirname(@getPath()), src))

    html

  showLoading: ->
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Markdown...'

  #FIXME: These need to be broken out nicer and more reusable
  fetchTodos: ->
    # console.log arguments
    # wipe out the array, to start fresh
    todoArray = []
    #capture the rest of the line after the todo
    atom.project.scan /TODO:(.+$)/, (e) -> #glob pattern. Ignore node_modules
      # console.log('RESULTS', e)
      # only keep the part we care about


      #loop through the results in the file, strip out 'todo:', and allow an optional space after todo:
      regExMatch.matchText = regExMatch.matchText.match(/TODO:\s?(.+$)/)[1] for regExMatch in e.matches

      # store in array
      todoArray.push(e)

  #FIXME: These need to be broken out nicer and more reusable
  fetchFixme: ->
    # console.log arguments
    # wipe out the array, to start fresh
    fixmeArray = []
    #capture the rest of the line after the todo
    atom.project.scan /FIXME:(.+$)/, (e) -> #glob pattern. Ignore node_modules

      #loop through the results in the file, strip out 'todo:', and allow an optional space after todo:
      regExMatch.matchText = regExMatch.matchText.match(/FIXME:\s?(.+$)/)[1] for regExMatch in e.matches

      # store in array
      fixmeArray.push(e)

  #CHANGED: something has changed
  fetchChanged: ->
    # console.log arguments
    # wipe out the array, to start fresh
    changedArray = []
    #capture the rest of the line after the todo
    atom.project.scan /CHANGED:(.+$)/, (e) -> #glob pattern. Ignore node_modules

      #loop through the results in the file, strip out 'todo:', and allow an optional space after todo:
      regExMatch.matchText = regExMatch.matchText.match(/CHANGED:\s?(.+$)/)[1] for regExMatch in e.matches

      # store in array
      changedArray.push(e)

  renderTodos: ->
    @showLoading()
    #FIXME: nesting this seems ugly
    @fetchTodos().then (contents) =>

      @fetchFixme().then (contents) =>

        @fetchChanged().then (contents) =>



          # wasn't able to load 'dust' properly for some reason
          dust = require('dust.js') #templating engine

          # template = hogan.compile("Hello {name}!");

          # team = ['jamis', 'adam', 'johnson']

          # load up the template
          # path.resolve __dirname, '../template/show-todo-template.html'
          templ_path = path.resolve(__dirname, '../template/show-todo-template.html')
          if ( fs.isFileSync(templ_path) )
            template = fs.readFileSync(templ_path, {encoding: "utf8"})

          console.log(todoArray)
          console.log 'template', template

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
            "todo_items": todoArray,
            "fixme_items": fixmeArray,
            "changed_items": changedArray
          }

          # render the template
          dust.render "todo-template", context, (err, out) =>
            console.log 'err', err
            # console.log('content to be rendered', out);
            @html(out)

      # team.map (fillName) =>
      #   # Render context to template
      #   console.log template
      #   console.log "template" template.render {name: fillName }
        # return template.render {name: fillName }






      # console.log "contents", todoArray
      # @html("markdown-spinner', 'Loading Markdown... asdfasdfas asdfasdf asdfasdf asdfadsf ")
      # @html(todoArray[0].matches[0].lineText)
      # @html(todoArray[1].matches[0].lineText)
      # @html $$$ ->
      #   @div todoArray[0].matches[0].lineText class: 'markdown-spinner', 'Loading Markdown...'

    # @file.read().then (contents) =>
    #   roaster = require 'roaster'
    #   sanitize = true
    #   roaster contents, {sanitize}, (error, html) =>
    #     if error
    #       @showError(error)
    #     else
    #       @html(@resolveImagePaths(html))
          # @html(@tokenizeCodeBlocks(@resolveImagePaths(html)))

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
