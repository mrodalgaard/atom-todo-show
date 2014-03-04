path = require 'path'
{$, $$$, EditorView, ScrollView} = require 'atom'
{File} = require 'pathwatcher'
fs = require 'fs-plus'

todoArray = []

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
    "#{path.basename(@getPath())} Preview"

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

  fetchTodos: ->
    console.log arguments
    atom.project.scan /TODO: /, {paths: ['/**/*', '!**/node_modules/**']}, (e) -> #glob pattern. Ignore node_modules
      # console.log(e)
      todoArray.push(e)
      # console.log arguments

  renderTodos: ->
    @showLoading()
    @fetchTodos().then (contents) =>
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
        "filter": (chunk, context, bodies) =>
          return chunk.tap((data) =>
            console.log(arguments)
            # FIXME: This seems dirty. Can we pass in the starting point?
            # take everything AFTER the TODO
            # data.sub
            console.log('data', data)
            console.log('context', context.stack.head.range[0][1])
            console.log('bodies', bodies)
            #TODO_match start
            match_start = context.stack.head.range[1][1]

            # only gives us the stuff after the match starts
            return data.substr(match_start);
          ).render(bodies.block, context).untap();
        ,
        "filterPath": (chunk, context, bodies) =>
          return chunk.tap((data) =>

            # make it relative
            return atom.project.relativize(data);
          ).render(bodies.block, context).untap();
        ,
        "todo_items": todoArray
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
    # FIXME: probably not necessary. Can Likely be removed.
    @subscribe @file, 'contents-changed', =>
      @renderTodos()
      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)


  # open a new window, and load the file that we need
  openPath: (filePath, lineNumber) ->
    return unless filePath

    atom.workspaceView.open(filePath, {@allowActiveEditorChange}).done =>
      @moveToLine(lineNumber)

  # toggle: ->
  #   @renderTodos()
  #   console.log "ShowTodoView was toggled!"
    # if @hasParent()
    #   @detach()
    # else
    #   atom.workspaceView.append(this)
