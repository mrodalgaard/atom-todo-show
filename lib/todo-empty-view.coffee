{View} = require 'atom-space-pen-views'

module.exports =
class TodoEmptyView extends View
  @content: ->
    @section =>
      @h1 "No results"
      @table =>
        @tr =>
          @td =>
            @h5 "Did not find any todos. Searched for:"
            @ul =>
              for regex in atom.config.get('todo-show.findTheseRegexes') by 2
                @li regex
            @h5 "Use your configuration to add more patterns."

  destroy: ->
    @detach()
