path = require 'path'
TodoModel = require '../lib/todo-model'

describe 'Todo Model', ->
  describe 'Create todo models', ->
    {match} = []

    beforeEach ->
      match =
        path: "#{atom.project.getPaths()[0]}/sample.c"
        all: ' TODO: Comment in C '
        regexp: /\b@?TODO:?\d*($|\s.*$)/g
        position: [
          [0, 1]
          [0, 20]
        ]

    it 'should handle results from workspace scan (also tested in fetchRegexItem)', ->
      delete match.regexp
      model = new TodoModel(match)
      expect(model.text).toEqual 'TODO: Comment in C'

    it 'should remove regex part', ->
      model = new TodoModel(match)
      expect(model.text).toEqual 'Comment in C'

    it 'should serialize range and relativize path', ->
      model = new TodoModel(match)
      expect(model.file).toEqual 'sample.c'
      expect(model.range).toEqual '0,1,0,20'

    it 'should handle invalid match position', ->
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

    it 'should extract todo tags', ->
      match.text = "test #TODO: 123 #tag1"
      model = new TodoModel(match)
      expect(model.tags).toBe 'tag1'
      expect(model.text).toBe '123'

      match.text = "#TODO: 123 #tag1."
      expect(new TodoModel(match).tags).toBe 'tag1'

    it 'should extract multiple todo tags', ->
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

    it 'should handle invalid tags', ->
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
