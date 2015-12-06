module.exports =
class TodosMarkdown
  constructor: ->
    @showInTable = atom.config.get('todo-show.showInTable')

  getItemOutput: (todo, key) ->
    if item = todo[key.toLowerCase()]
      switch key
        when 'All' then " #{item}"
        when 'Text' then " #{item}"
        when 'Type' then " __#{item}__"
        when 'Range' then " _:#{item}_"
        when 'Line' then " _:#{item}_"
        when 'Regex' then " _'#{item}'_"
        when 'File' then " [#{item}](#{item})"
        when 'Tags' then " _#{item}_"

  getTable: (todos) ->
    md =  "| #{(for key in @showInTable then key).join(' | ')} |\n"
    md += "|#{Array(md.length-2).join('-')}|\n"
    md + (for todo in todos
      out = '|' + (for key in @showInTable
        @getItemOutput(todo, key)
      ).join(' |')
      "#{out} |\n"
    ).join('')

  getList: (todos) ->
    (for todo in todos
      out = '-' + (for key in @showInTable
        @getItemOutput(todo, key)
      ).join('')
      out = "- No details" if out is '-'
      "#{out}\n"
    ).join('')

  markdown: (todos) ->
    if atom.config.get('todo-show.saveOutputAs') is 'Table'
      @getTable todos
    else
      @getList todos
