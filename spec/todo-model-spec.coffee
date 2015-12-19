path = require 'path'
TodoModel = require '../lib/todo-model'

describe "Todo Model", ->
  {match} = []

  beforeEach ->
    match =
      path: "#{atom.project.getPaths()[0]}/sample.c"
      all: " TODO: Comment in C #tag1 "
      type: "TODOs"
      regexp: /\b@?TODO:?\d*($|\s.*$)/g
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

    it "should serialize range and relativize path", ->
      model = new TodoModel(match)
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

  describe "Model properties", ->
    it "returns value for key", ->
      model = new TodoModel(match)
      expect(model.get('All')).toBe match.all
      expect(model.get('File')).toBe 'sample.c'
      expect(model.get('Line')).toBe '1'
      expect(model.get('Path')).toBe match.path
      expect(model.get('Range')).toBe '0,1,0,20'
      expect(model.get('RegExp')).toBe match.regexp
      expect(model.get('Tags')).toBe 'tag1'
      expect(model.get('Text')).toBe 'Comment in C'

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
