
# This is a coffee-script port for Parsedown (http://parsedown.org)
# author: joyqi (http://www.l4zy.com)
# homepage: http://github.com/joyqi/parsedown-coffee

# clone object
clone = (obj) ->
    if not obj? or typeof obj isnt 'object'
        return obj

    newInstance = new obj.constructor()

    for key of obj
        newInstance[key] = clone obj[key]

    return newInstance

# Parsedown Class
class @Parsedown

    # init all pre definition types
    constructor: (@breaksEnabled = no) ->
        @blockTypes =
            '#' : ['Atx']
            '*' : ['Rule', 'List']
            '+' : ['List']
            '-' : ['Setext', 'Table', 'Rule', 'List']
            '0' : ['List']
            '1' : ['List']
            '2' : ['List']
            '3' : ['List']
            '4' : ['List']
            '5' : ['List']
            '6' : ['List']
            '7' : ['List']
            '8' : ['List']
            '9' : ['List']
            ':' : ['Table']
            '<' : ['Comment', 'Markup']
            '=' : ['Setext']
            '>' : ['Quote']
            '_' : ['Rule']
            '`' : ['FencedCode']
            '|' : ['Table']
            '~' : ['FencedCode']

        @definitionTypes =
            '[' : ['Reference']

        @unmarkedBlockTypes = ['CodeBlock']

        @spanTypes =
            '!' : ['Link']
            '&' : ['Ampersand']
            '*' : ['Emphasis']
            '/' : ['Url']
            '<' : ['UrlTag', 'EmailTag', 'Tag', 'LessThan']
            '[' : ['Link']
            '_' : ['Emphasis']
            '`' : ['InlineCode']
            '~' : ['Strikethrough']
            '\\' : ['EscapeSequence']

        @spanMarkerList = '*_!&[</`~\\'

        @specialCharacters = ['\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '>', '#', '+', '-', '.', '!']
        
        @strongRegex =
            '*' : /^[*]{2}((?:[^*]|[*][^*]*[*])+?)[*]{2}(?![*])/
            '_' : /^__((?:[^_]|_[^_]*_)+?)__(?!_)/

        @emRegex =
            '*' : /^[*]((?:[^*]|[*][*][^*]+?[*][*])+?)[*](?![*])/
            '_' : /^_((?:[^_]|__[^_]*__)+?)_(?!_)\b/

        @textLevelElements = [
            'a', 'br', 'bdo', 'abbr', 'blink', 'nextid', 'acronym', 'basefont',
            'b', 'em', 'big', 'cite', 'small', 'spacer', 'listing',
            'i', 'rp', 'del', 'code',          'strike', 'marquee',
            'q', 'rt', 'ins', 'font',          'strong',
            's', 'tt', 'sub', 'mark',
            'u', 'xm', 'sup', 'nobr',
                    'var', 'ruby',
                    'wbr', 'span',
                            'time',
        ]

    # make html
    makeHtml: (text) ->
        @definitions = {}

        text = text.replace "\r\n", "\n"
            .replace "\r", "\n"
            .replace "\t", "    "

        text = trim text, "\n"

        lines = text.split "\n"
        markup = @lines lines

        trim markup, "\n"

    # parse lines
    lines: (lines) ->
        currentBlock = null
        elements = []

        for line in lines
            
            if (rtrim line) == ''
                currentBlock.interrupted = yes if currentBlock?
                continue

            indent = 0
            indent += 1 while line[indent]? and line[indent] == ' '

            text = if indent > 0 then line.substring indent else line

            line =
                'body'  :   line
                'indent':   indent
                'text'  :   text

            if currentBlock? and currentBlock.incomplete?
                block = @['addTo' + currentBlock.type] line, currentBlock

                if block?
                    currentBlock = block
                    continue
                else
                    currentBlock = @['complete' + currentBlock.type] currentBlock if @['complete' + currentBlock.type]?
                    delete currentBlock.incomplete

            marker = text[0]
            pass = no           # continue 2

            if @definitionTypes[marker]?
                for definitionType in @definitionTypes[marker]
                    definition = @['identify' + definitionType] line, currentBlock

                    if definition?
                        @definitions[definitionType] = {} if not @definitions[definitionType]?
                        @definitions[definitionType][definition.id] = definition.data
                        pass = yes
                        break
            
            continue if pass

            blockTypes = clone @unmarkedBlockTypes

            if @blockTypes[marker]?
                blockTypes.push blockType for blockType in @blockTypes[marker]

            for blockType in blockTypes
                block = @['identify' + blockType] line, currentBlock

                if block?
                    block.type = blockType

                    if not block.identified?
                        elements.push \
                            if currentBlock? then currentBlock.element else null
                        block.identified = yes

                    block.incomplete = yes if @['addTo' . blockType]?
                    currentBlock = block
                    pass = yes
                    break

            continue if pass

            if currentBlock? and not currentBlock.type? and not currentBlock.interrupted?
                currentBlock.element.text += "\n" + text
            else
                elements.push \
                    if currentBlock? then currentBlock.element else null
                currentBlock = @buildParagraph line
                currentBlock.identified = yes

        if currentBlock? and currentBlock.incomplete? and @['complete' + currentBlock.type]
            currentBlock = @['complete' + currentBlock.type] currentBlock

        elements.push \
            if currentBlock? then currentBlock.element else null
        elements.shift()

        @elements elements


    # Atx
    identifyAtx: (line) ->
        if line.text[1]?
            level = 1
            level += 1 while line.text.level? and line.text.level == '#'

            text = trim line.text, '# '
            
            block =
                'element':
                    'name'      :   'h' + (Math.min 6, level)
                    'text'      :   text
                    'handler'   :   'line'
 

    # Code
    identifyCodeBlock: (line) ->
        if line.indent >= 4
            text = line.body.substring 4

            block =
                'element':
                    'name'      :   'pre'
                    'handler'   :   'element'
                    'text':
                        'name'  :   'code'
                        'text'  :   text


    addToCodeBlock: (line, block) ->
        if line.indent >= 4
            if block.interrupted?
                block.element.text.text += "\n"
                delete block.interrupted

            block.element.text.text += "\n"
            text = line.body.substring 4
            block.element.text.text += text
            block


    completeCodeBlock: (block) ->
        text = htmlspecialchars block.element.text.text, 'ENT_NOQUOTES', 'UTF-8'
        block.element.text.text = text
        block

    
    # Comment
    identifyComment: (line) ->
        if line.text[3]? and line.text[3] == '-' and line.text[2] == '-' and line.text[1] == '!'
            block =
                'element' : line.body
            
            block.closed = yes if line.text.match /-->$/
            block


    addToComment: (line, block) ->
        return if block.closed?

        block .element += "\n" + line.body

        block.closed = yes if line.text.match /-->$/
        block


    # Fenced code
    identifyFencedCode: (line) ->
        re = new RegExp "^([#{line.text[0]}]{3,})[ ]*([\\w-]+)?[ ]*$"

        if matches = re.exec line.text
            element =
                'name'  :   'code'
                'text'  :   ''

            if matches[2]?
                cls = 'language-' + matches[2]
                element.attributes =
                    'class' :   cls

            block =
                'char'      :   line.text[0]
                'element'   :
                    'name'      :   'pre'
                    'handler'   :   'element'
                    'text'      :   element


    addToFencedCode: (line, block) ->
        return if block.complete?
        
        if block.interrupted?
            block.element.text.text += "\n"
            delete block.interrupted

        re = new RegExp "^#{block.char}{3,}[ ]*$"
        if re.text line.text
            block.element.text.text = block.element.text.text.substring 1
            block.complete = yes
            return block

        block.element.text.text += "\n" + line.body
        block


    completeFencedCode: (block) ->
        text = htmlspecialchars block.element.text.text, 'ENT_NOQUOTES', 'UTF-8'
        block.element.text.text = text
        block


    # List
    identifyList: (line) ->
        [name, pattern] = if line.text.charCodeAt(0) <= '-'.charCodeAt(0) then ['ul', '[*+-]'] else ['ol', '[0-9]+[.]']

        re = new RegExp "^(#{pattern}[ ]+)(.*)"
        if matches = re.exec line.text
            block =
                'indent'    :   line.indent
                'pattern'   :   pattern
                'element'   :
                    'name'      :   name
                    'handler'   :   'elements'
                    'text'      :   []

            block.li =
                'name'      :   'li'
                'handler'   :   'li'
                'text'      :   [matches[2]]

            block.element.text.push block.li
            block

    
    addToList: (line, block) ->
        re = new RegExp "^#{block.pattern}[ ]+(.*)"
        if block.indent == line.indent and matches = re.exec line.text
            if block.interrupted?
                block.li.text.push ''
                delete block.interrupted

            delete block.li
            
            block.li =
                'name'      :   'li'
                'handler'   :   'li'
                'text'      :   [matches[1]]

            return block

        else if not block.interrupted?
            
            text = line.body.replace /^[ ]{0,4}/, ''
            block.li.text.push text
            return block

        else if line.indent > 0
            
            block.li.text.push ''
            text = line.body.replace /^[ ]{0,4}/, ''
            block.li.text.push text
            delete block.interrupted
            return block


    # Quote
    identifyQuote: (line) ->
        if matches = /^>[ ]?(.*)/.exec line.text
            block =
                'element':
                    'name'      :   'blockquote'
                    'handler'   :   'lines'
                    'text'      :   [matches[1]]


    addToQuote: (line, block) ->
        if line.text[0] == '>' and matches = /^>[ ]?(.*)/.exec line.text
            if block.interrupted?
                block.element.text.push ''
                delete block.interrupted

            block.element.text.push matches[1]
            return block

        else if not block.interrupted?
            block.element.text.push line.text
            return block


    # Rule
    identifyRule: (line) ->
        re = new RegExp "^([#{line.text[0]}])([ ]{0,2}\\1){2,}[ ]*$"
        if re.test line.text
            block =
                'element':
                    'name'  :   'hr'

    # Setext
    identifySetext: (line, block = null) ->
        return if not block? or block.type? or block.interrupted?
        
        if (rtrim line.text, line.text[0]) == ''
            block.element.name = if line.text[0] == '=' then 'h1' else 'h2'
            return block


    # Markup
    identifyMarkup: (line) ->
        if matches = /^<(\w[\w\d]*)(?:[ ][^>]*)?(\/?)[ ]*>/.exec line.text
            return if matches[1] in @textLevelElements

            block =
                'element'   :   line.body

            re = new RegExp "</#{matches[1]}>[ ]*$"
            if matches[2]? or matches[1] == 'hr' or re.test line.text
                block.closed = yes
            else
                block.depth = 0
                block.name = matches[1]

            return block

    
    addToMarkup: (line, block) ->
        return if block.closed

        re = new RegExp "<#{block.name}([ ][^/]+)?>"
        if re.test line.text
            block.depth += 1

        if stripos line.text, "</#{block.name}>" != false
            if block.depth > 0
                block.depth -= 1
            else
                block.closed = yes

        block.element += "\n" + line.body
        return block


    # Table
    identifyTable: (line, block = null) ->
        return if not block? or block.type? or block.interrupted?

        if block.element.text.indexOf '|' >= 0 and rtrim line.text, ' -:|' == ''
            alignments = []
            divider = line.text
            divider = trim divider
            divider = trim divider, '|'

            dividerCells = divider.splig '|'

            for dividerCell in dividerCells
                dividerCell = trim dividerCell
                continue if dividerCell == ''

                alignment = if dividerCell[0] == ':' then 'left' else null
                if dividerCell.substring 0, dividerCell.length - 1 == ':'
                    alignment = if alignment == 'left' then 'center' : 'right'
                alignments.push alignment

            headerElements = []
            header = block.element.text

            header = trim header
            header = trim header, '|'

            headerCells = header.split '|'

            for headerCell, index in headerCells
                headerCell = trim headerCell

                headerElement =
                    'name'      :   'th'
                    'text'      :   headerCell
                    'handler'   :   'line'

                if alignments[index]?
                    alignment = alignments[index]

                    headerElement.attributes =
                        'align' :   alignment

                headerElements.push = headerElement

            block =
                'alignments'    :   alignments
                'identified'    :   yes
                'element'       :
                    'name'      :   'table'
                    'handler'   :   'elements'
                    'text'      :   []

            block.element.text.push
                'name'      :   'thead'
                'handler'   :   'elements'
                'text'      :   []

            block.element.text.push
                'name'      :   'tbody'
                'handler'   :   'elements'
                'text'      :   []

            block.element.text[0].text.push
                'name'      :   'tr'
                'handler'   :   'elements'
                'text'      :   headerElements

            return block


    addToTable: (line, block) ->
        if line.text[0] == '|' or line.text.indexOf '|' > 0
            elements = []

            row = trim line.text
            row = trim row, '|'

            cells = row.split '|'

            for cell, index in cells
                cell = trim cell

                element =
                    'name'      :   'td'
                    'handler'   :   'line'
                    'text'      :   cell

                if block.alignments[index]?
                    element.attributes =
                        'align' :   block.alignments[index]

                elements.push element

            element =
                'name'      :   'tr'
                'handler'   :   'elements'
                'text'      :   elements

            block.element.text[1].text.push element
            return block


    # Definitions
    identifyReference: (line) ->
        if matches = /^\[(.+?)\]:[ ]*<?(\S+?)>?(?:[ ]+["'(](.+)["')])?[ ]*$/.exec line.text
            definition =
                'id'    :   matches[1].toLowerCase()
                'data'  :
                    'url'   :   matches[2]

            if matches[3]?
                definition.data.title = matches[3]

            return definition

    buildParagraph: (line) ->
        block =
            'element':
                'name'      :   'p'
                'text'      :   line.text
                'handler'   :   'line'

    element: (element) ->
        markup = '<' + element.name

        if element.attributes?
            for value, name in element.attributes
                markup += ' ' + name + '="' + value + '"'
        
        if element.text?
            markup += '>'

            if element.handler?
                markup += @[element.handler] element.text
            else
                markup += element.text

            markup += '</' + element.name + '>'
        else
            markup += ' />'

    
    elements: (elements) ->
        markup = ''

        for element in elements
            continue if element == null

            markup += "\n"

            if typeof element == 'string'
                markup += element
                continue

            markup += @element element

        markup += "\n"

    line: (text) ->
        markup = ''
        remainder = text
        markerPosition = 0

        while excerpt = strpbrk remainder, @spanMarkerList
            marker = excerpt[0]
            markerPosition += remainder.indexOf marker

            pass = no
            iExcerpt =
                'text'      :   excerpt
                'context'   :   text

            for spanType in @spanTypes[marker]
                handler = 'identify' + spanType
                span = @[handler] iExcerpt

                continue if not span?
                continue if span.position? and span.position > markerPosition

                span.position = markerPosition if not span.position?
                plainText = text.substring 0, span.position
                markup += @readPlainText plainText
                markup += if span.markup then span.markup else @element span.element

                text = text.substring span.position + span.extent
                remainder = text
                markerPosition = 0
                pass = yes
                break

            continue if pass

            remainder = excerpt.substring 1
            markerPosition += 1

        markup += @readPlainText text


    identifyUrl: (excerpt) ->
        return if not excerpt.text[1] or excerpt.text[1] != '/'
        
        if matches = /\bhttps?:[\/]{2}[^\s<]+\b\/*/ig.exec excerpt.context
            url = matches[0].replace '&', '&amp;'
                .replace '<', '&lt;'

            'extent'    :   matches[0].length
            'position'  :   matches.index
            'element'   :
                'name'  :   'a'
                'text'  :   url
                'attributes':
                    'href'  :   url
    

    identifyAmpersand: (excerpt) ->
        if not /^&#?\w+;/.test excerpt.text
            'markup'    :   '&amp;'
            'extent'    :   1


    identifyStrikethrough: (excerpt) ->
        return if not excerpt.text[1]

        if excerpt.text[1] == '~' and matches = /^~~(?=\S)(.+?)(?<=\S)~~/.exec excerpt.text
            'extent'    :   matches[0].length
            'element'   :
                'name'      :   'del'
                'text'      :   matches[1]
                'handler'   :   'line'


    identifyEscapeSequence: (excerpt) ->
        if excerpt.text[1]? and excerpt.text[1] in @specialCharacters
            
            'markup'    :   excerpt.text[1]
            'extent'    :   2


    identifyUrlTag: (excerpt) ->
        if excerpt.text.indexOf '>' >= 0 and matches = /^<(https?:[\/]{2}[^\s]+?)>/i.exec excerpt.text
            url = matches[1].replace '&', '&amp;'
                .replace '<', '&lt'

            'extent'    :   matches[0]
            'element'   :
                'name'      :   'a'
                'text'      :   url
                'attributes':
                    'href'  :   url


    identifyEmailTag: (excerpt) ->
        if excerpt.text.indexOf '>' >= 0 and matches = /^<(\S+?@\S+?)>/.exec excerpt.text
            'extent'    :   matches[0]
            'element'   :
                'name'      :   'a'
                'text'      :   matches[1]
                'attributes':
                    'href'  :   'mailto:' . matches[1]


    identifyTag: (excerpt) ->
        if excerpt.text.indexOf '>' >= 0 and matches = /^<\/?\w.*?>/.exec excerpt.text
            'markup'    :   matches[0]
            'extent'    :   matches[0].length


    identifyInlineCode: (excerpt) ->
        marker = excerpt.text[0]

        re = new RegExp "^(#{marker}+)[ ]*(.+?)[ ]*(?<!#{marker})\\1(?!#{marker})"

        if matches = re.exec excerpt.text
            text = matches[2]
            text = htmlspecialchars text, 'ENT_NOQUOTES', 'UTF-8'

            'extent'    :   matches[0].length
            'element'   :
                'name'  :   'code'
                'text'  :   text


    identifyLink: (excerpt) ->
        console.log excerpt
        extent = if excerpt.text[0] == '!' then 1 else 0

        if excerpt.text.indexOf ']' > 0 and matches = /\[((?:[^][]|(?R))*)\]/.exec excerpt.text
            link =
                'text'  :   matches[1]
                'label' :   matches[1].toLowerCase()

            extent += matches[0].length
            substring = excerpt.text.substring extent

            if matches = /^\s*\[([^][]+)\]/.exec substring
                link.label = matches[1].toLowerCase()

                if @definitions.reference[link.label]?
                    for key, val of @definitions.reference[link.label] when not link[key]?
                        link[key] = val
                    extent += matches[0].length
                else
                    return
            else if @definitions.reference[link.label]?
                for key, val of @definitions.reference[link.label] when not link[key]?
                    link[key] = val

                if match = /^[ ]*\[\]/.exec substring
                    extent += matches[0].length
            else if matches = /^\([ ]*(.*?)(?:[ ]+['"](.+?)['"])?[ ]*\)/.exec substring
                link.url = matches[1]
                link.title = matches[2] if matches[2]?
                extent += matches[0].length
            else
                return
        else
            return

        url = link.url.replace '&', '&amp;'
            .replace '<', '&lt;'

        if excerpt.text[0] != '!'
            element =
                'name'  :   'img'
                'attributes':
                    'alt'   :   link.text
                    'src'   :   url
        else
            element =
                'name'      :   'a'
                'handler'   :   'line'
                'text'      :   link.text
                'attributes':
                    'href'  :   url

        element.attributes.title = link.title if link.title?
            
        'extent'    :   extent
        'element'   :   element


    identifyEmphasis: (excerpt) ->
        return if not excerpt.text[1]?

        marker = excerpt.text[0]

        if excerpt.text[1] == marker and matches = @strongRegex[marker].exec excerpt.text
            emphasis = 'strong'
        else if matches = @emRegex[marker].exec excerpt.text
            emphasis = 'em'
        else
            return

        'extent'    :   matches[0].length
        'element'   :
            'name'      :   emphasis
            'handler'   :   'line'
            'text'      :   matches[1]

    readPlainText: (text) ->
        breakMarker = if @breaksEnabled then "\n" else " \n"
        text.replace breakMarker, "<br />\n"


    li: (lines) ->
        markup = @lines lines
        trimmedMarkup = trim markup

        if '' not in lines and trimmedMarkup.substring 0, 3 == '<p>'
            markup = trimmedMarkup.substring 3
            position = markup.indexOf '</p>'
            markup = substr_replace markup, '', position, 4

        return markup

