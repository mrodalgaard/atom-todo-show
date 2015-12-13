module.exports =
class TodosMarkdown
  constructor: ->
    @showInTable = atom.config.get('todo-show.showInTable')

  getTable: (todos) ->
    md =  "| #{(for key in @showInTable then key).join(' | ')} |\n"
    md += "|#{Array(md.length-2).join('-')}|\n"
    md + (for todo in todos
      out = '|' + todo.getMarkdownArray(@showInTable).join(' |')
      "#{out} |\n"
    ).join('')

  getList: (todos) ->
    (for todo in todos
      out = '-' + todo.getMarkdownArray(@showInTable).join('')
      out = "- No details" if out is '-'
      "#{out}\n"
    ).join('')

  markdown: (todos) ->
    if atom.config.get('todo-show.saveOutputAs') is 'Table'
      @getTable todos
    else
      @getList todos
