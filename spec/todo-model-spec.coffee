path = require 'path'

TodoModel = require '../lib/todo-model'
ShowTodo = require '../lib/show-todo'
TodoRegex = require '../lib/todo-regex'

sample1Path = path.join(__dirname, 'fixtures/sample1')

describe "Todo Model", ->
  {match, todoRegex} = []

  beforeEach ->
    atom.project.setPaths [sample1Path]
    todoRegex = new TodoRegex(
      ShowTodo.config.findUsingRegex.default
      ['FIXME', 'TODO']
    )

    match =
      all: " TODO: Comment in C #tag1 "
      loc: "#{atom.project.getPaths()[0]}/sample1/sample.c"
      regex: todoRegex.regex
      regexp: todoRegex.regexp
      position: [
        [0, 1]
        [0, 20]
      ]

  describe "Create todo models", ->
    it "should handle results from workspace scan (also tested in fetchRegexItem)", ->
      delete match.regexp
      model = new TodoModel(match)
      expect(model.text).toEqual "TODO: Comment in C"

    it "should remove regex part", ->
      model = new TodoModel(match)
      expect(model.text).toEqual "Comment in C"

    it "should serialize range, relativize path and extract basename", ->
      model = new TodoModel(match)
      expect(model.path).toEqual 'sample1/sample.c'
      expect(model.file).toEqual 'sample.c'
      expect(model.range).toEqual '0,1,0,20'

    it "should handle invalid match position", ->
      delete match.position
      model = new TodoModel(match)
      expect(model.range).toEqual '0,0'
      expect(model.position).toEqual [[0,0]]

      match.position = []
      model = new TodoModel(match)
      expect(model.range).toEqual '0,0'
      expect(model.position).toEqual [[0,0]]

      match.position = [[0,1]]
      model = new TodoModel(match)
      expect(model.range).toEqual '0,1'
      expect(model.position).toEqual [[0,1]]

      match.position = [[0,1],[2,3]]
      model = new TodoModel(match)
      expect(model.range).toEqual '0,1,2,3'
      expect(model.position).toEqual [[0,1],[2,3]]

    it "should handle invalid match position with no matchText", ->
      match.all = "TODO"
      delete match.position
      model = new TodoModel(match)
      expect(model.text).toEqual 'No details'
      expect(model.range).toEqual '0,0'
      expect(model.position).toEqual [[0,0]]

      match.position = []
      model = new TodoModel(match)
      expect(model.range).toEqual '0,0'
      expect(model.position).toEqual [[0,0]]

      match.position = true
      model = new TodoModel(match)
      expect(model.range).toEqual '0,0'
      expect(model.position).toEqual [[0,0]]

    it "should handle dot after todo", ->
      match.all = "// TODO. comment"
      model = new TodoModel(match)
      expect(model.text).toBe 'comment'

    it "should handle semicolon after todo", ->
      match.all = "// TODO; comment"
      model = new TodoModel(match)
      expect(model.text).toBe 'comment'

    it 'respects imdone syntax', ->
      match.all = "// TODO:10 todo1"
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'todo1'

    it 'respects imdone syntax zero', ->
      match.all = "// TODO:0 todo2"
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'todo2'

    it 'handles number in todo', ->
      match.all = "Line 1 //TODO: 1 2 3"
      model = new TodoModel(match)
      expect(model.text).toBe '1 2 3'

    it 'handles number in todo (as long as its not without space)', ->
      match.all = "Line 2 //TODO:1 2 3"
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe '2 3'

    it 'handles empty todos', ->
      match.all = "Line 1 //TODO"
      match.position = [[0,9],[0,13]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'Line 1'

    it 'handles empty todos with other comment characters', ->
      match.all = "Line 2 # TODO"
      match.position = [[0,9],[0,13]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'Line 2'

    it 'handles empty todos with separator', ->
      match.all = "Line 3 // TODO."
      match.position = [[0,9],[0,14]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'Line 3'

    it 'handles empty todos with colon separator', ->
      match.all = "Line 4 // TODO:"
      match.position = [[0,10],[0,14]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'Line 4'

    it 'handles empty block todos', ->
      match.all = "Line 5 /* TODO */ "
      match.position = [[0,9],[0,19]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'Line 5'

    it 'handles completely empty todos', ->
      match.all = "// TODO"
      match.position = [[0,2],[0,7]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'No details'

    it 'handles completely empty todos with separator', ->
      match.all = "// TODO."
      match.position = [[0,2],[0,8]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'No details'

    it 'handles completely empty block todos', ->
      match.all = " /* TODO */ "
      match.position = [[0,3],[0,12]]
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.text).toBe 'No details'

    it 'handles todos with @ in front', ->
      match.all = "Line 1 // @TODO: text 1"
      model = new TodoModel(match)
      expect(model.text).toBe 'text 1'

    it 'handles todos with @ in front', ->
      match.all = "Line 2 @TODO: text 2"
      model = new TodoModel(match)
      expect(model.text).toBe 'text 2'

    it 'handles tabs in todos', ->
      match.all = "Line //TODO:\ttext"
      model = new TodoModel(match)
      expect(model.text).toBe 'text'

    it 'handles todo without semicolon', ->
      match.all = "A line // TODO text"
      model = new TodoModel(match)
      expect(model.text).toBe 'text'

    it 'stops with invalid todos', ->
      text = "A line // TODO:text"
      match.all = text
      model = new TodoModel(match)
      expect(model.type).toBe undefined
      expect(model.text).toBe text

    it 'extracts project name', ->
      model = new TodoModel(match)
      expect(model.project).toBe 'sample1'

    it 'handles non-existing projects', ->
      atom.project.setPaths []
      model = new TodoModel(match)
      expect(model.project).toBe ''
      expect(model.file).toBe 'sample.c'
      expect(model.path).toBe match.loc

    it 'handles files not in project', ->
      match.loc = 'nonexisting/sample.c'
      model = new TodoModel(match)
      expect(model.project).toBe ''
      expect(model.file).toBe 'sample.c'
      expect(model.path).toBe match.loc

  describe "Extracting todo tags", ->
    it "should extract todo tags", ->
      match.text = "test #TODO: 123 #tag1"
      model = new TodoModel(match)
      expect(model.tags).toBe 'tag1'
      expect(model.text).toBe '123'

      match.text = "#TODO: 123 #tag1."
      expect(new TodoModel(match).tags).toBe 'tag1'

      match.text = "  TODO: 123 #tag1  "
      model = new TodoModel(match)
      expect(model.tags).toBe 'tag1'
      expect(model.text).toBe '123'

      match.text = "<!-- TODO: 123 #tag1   --> "
      model = new TodoModel(match)
      expect(model.tags).toBe 'tag1'
      expect(model.text).toBe '123'

      match.text = "<!-- TODO: Fix this link. #bug. -->"
      model = new TodoModel(match)
      expect(model.tags).toBe 'bug'
      expect(model.text).toBe 'Fix this link.'

    it "should extract multiple todo tags", ->
      match.text = "TODO: 123 #tag1 #tag2 #tag3"
      model = new TodoModel(match)
      expect(model.tags).toBe 'tag1, tag2, tag3'
      expect(model.text).toBe '123'

      match.text = "test #TODO: 123 #tag1, #tag2"
      expect(new TodoModel(match).tags).toBe 'tag1, tag2'

      match.text = "TODO: #123 #tag1"
      model = new TodoModel(match)
      expect(model.tags).toBe '123, tag1'
      expect(model.text).toBe 'No details'

    it "should handle invalid tags", ->
      match.text = "#TODO: 123 #tag1 X"
      expect(new TodoModel(match).tags).toBe ''

      match.text = "#TODO: 123 #tag1#"
      expect(new TodoModel(match).tags).toBe ''

      match.text = "#TODO: #tag1 todo"
      expect(new TodoModel(match).tags).toBe ''

      match.text = "#TODO: #tag.123"
      expect(new TodoModel(match).tags).toBe ''

      match.text = "#TODO: #tag1 #tag2@"
      expect(new TodoModel(match).tags).toBe ''

      match.text = "#TODO: #tag1, #tag2$, #tag3"
      expect(new TodoModel(match).tags).toBe 'tag3'

  describe "Handling google style guide todo syntax", ->
    it "adds an id to the model", ->
      match.all = "// TODO(kl@gmail.com): Use a *."
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.id).toBe 'kl@gmail.com'
      expect(model.text).toBe 'Use a *.'

    it "handles plain name", ->
      match.all = "// TODO(Zeke) change this to use relations."
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.id).toBe 'Zeke'
      expect(model.text).toBe 'change this to use relations.'

    it "handles spaces", ->
      match.all = "// TODO(bug 12345): remove the \"Last visitors\" feature"
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.id).toBe 'bug 12345'
      expect(model.text).toBe 'remove the "Last visitors" feature'

    it "handles parentheses in text", ->
      match.all = "// TODO(bug): another task (seriously)"
      model = new TodoModel(match)
      expect(model.type).toBe 'TODO'
      expect(model.id).toBe 'bug'
      expect(model.text).toBe 'another task (seriously)'

    it "handles long ids with empty todos", ->
      match.all = "// TODO(id: Use a *.)"
      match.position = [[0,2],[0,21]]
      model = new TodoModel(match)
      expect(model.id).toBe 'id: Use a *.'
      expect(model.text).toBe 'No details'

    it "handles invalid todo id format", ->
      match.all = "// TODO(id: Use a *."
      model = new TodoModel(match)
      expect(model.id).toBe ''
      expect(model.text).toBe '(id: Use a *.'

    it "handles invalid id with underscore", ->
      match.all = "// TODO _(id): Use a *."
      model = new TodoModel(match)
      expect(model.id).toBe ''
      expect(model.text).toBe '_(id): Use a *.'

    it "handles invalid id with space", ->
      match.all = "// TODO (id): Use a *."
      model = new TodoModel(match)
      expect(model.id).toBe ''
      expect(model.text).toBe '(id): Use a *.'

  describe "Model properties", ->
    it "returns value for key", ->
      model = new TodoModel(match)
      expect(model.get('All')).toBe match.all
      expect(model.get('Text')).toBe 'Comment in C'
      expect(model.get('Type')).toBe 'TODO'
      expect(model.get('Range')).toBe '0,1,0,20'
      expect(model.get('Line')).toBe '1'
      expect(model.get('Regex')).toBe '/\\b(TODO)[:;.,]?\\d*($|\\s.*$|\\(.*$)/g'
      expect(model.get('Path')).toBe 'sample1/sample.c'
      expect(model.get('File')).toBe 'sample.c'
      expect(model.get('Tags')).toBe 'tag1'
      expect(model.get('Id')).toBe ''
      expect(model.get('Project')).toBe 'sample1'
      expect(model.get('RegExp')).toBe match.regexp

    it "defaults to text", ->
      model = new TodoModel(match)
      expect(model.get()).toBe 'Comment in C'
      expect(model.get('NONEXISTING')).toBe 'Comment in C'

      delete match.all
      delete match.text
      model = new TodoModel(match)
      expect(model.get()).toBe 'No details'

      delete model.all
      delete model.text
      expect(model.get()).toBe 'No details'

    it "searches for strings", ->
      model = new TodoModel(match)
      expect(model.contains('Comment')).toBe true
      expect(model.contains('TODO')).toBe false

      atom.config.set 'todo-show.showInTable', ['Text', 'Type', 'Line']
      model = new TodoModel(match)
      expect(model.contains('Comment')).toBe true
      expect(model.contains('TODO')).toBe true
      expect(model.contains('1')).toBe true
      expect(model.contains('sample.c')).toBe false
      expect(model.contains('0,1')).toBe false
      expect(model.contains('')).toBe true
      expect(model.contains()).toBe true
