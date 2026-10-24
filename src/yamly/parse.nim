import std / [strutils, options, typetraits]
from std / unicode import Rune, toUTF8

type
  YamlOwner* = enum
    ## what introduced the value being parsed
    ownerKey  ## a mapping key (`key: value`)
    ownerDash ## a block sequence entry (`- value`)
    ownerTop  ## the start of the document
  YamlParseContext* = object
    data*: string
    idx*: int
    ind*: int ## column of the owner (key or dash) of the current value, -1 at top level
    owner*: YamlOwner
    flow*: int ## nesting depth of flow collections (`[...]` and `{...}`)
  YamlError* = object of ValueError

template ch*(y: YamlParseContext): char = y.data[y.idx]

template hasChar*(y: YamlParseContext): bool = y.idx < y.data.len

template inc*(y: var YamlParseContext) = inc y.idx

proc peek*(y: YamlParseContext, offset = 0): char =
  ## char at offset from current position, '\0' when out of data
  let i = y.idx + offset
  if i >= 0 and i < y.data.len: y.data[i] else: '\0'

proc col*(y: YamlParseContext): int =
  ## column of current position
  var i = y.idx - 1
  while i >= 0 and y.data[i] notin {'\n', '\r'}:
    dec i
  y.idx - i - 1

proc atLineStart*(y: YamlParseContext): bool =
  ## true if only spaces precede current position on its line
  var i = y.idx - 1
  while i >= 0 and y.data[i] == ' ':
    dec i
  i < 0 or y.data[i] in {'\n', '\r'}

proc line*(y: YamlParseContext): int =
  ## line number (starting from 1) of current position
  result = 1
  for i in 0 ..< min(y.idx, y.data.len):
    if y.data[i] == '\n':
      inc result

template error*(y: YamlParseContext, msg: string) =
  ## Shortcut to raise an exception.
  raise newException(YamlError, msg & " At line " & $y.line & ", column " &
    $y.col & " (offset: " & $y.idx & ")")

const
  lineBreaks = {'\n', '\r'}
  flowIndicators = {',', '[', ']', '{', '}'}

when defined(release):
  {.push checks: off, inline.}

proc eatSpace*(y: var YamlParseContext): int =
  ## consumes whitespace (only space, no tabs, no newline!)
  ## and returns how much it has eaten
  let idx = y.idx
  while y.hasChar and y.ch == ' ':
    inc y.idx
  y.idx - idx

proc eatLine(y: var YamlParseContext) =
  ## consumes everything up to (and including) the next line break
  while y.hasChar and y.ch notin lineBreaks:
    inc y
  if y.hasChar and y.ch == '\r':
    inc y
  if y.hasChar and y.ch == '\n':
    inc y

proc eatSpaceAndComments*(y: var YamlParseContext): int =
  ## eats away space, newlines and comments and returns the column of what follows
  ## it does NOT change y's indentation
  while y.hasChar:
    case y.ch
    of ' ', '\n', '\r':
      inc y
    of '\t':
      y.error("Tabs are not allowed as whitespace.")
    of '#':
      while y.hasChar and y.ch notin lineBreaks:
        inc y
    else:
      break
  y.col

proc isDocMarker*(y: YamlParseContext): bool =
  ## true if at a document start (`---`) or end (`...`) marker
  y.col == 0 and y.idx + 2 < y.data.len and
    y.data[y.idx .. y.idx + 2] in ["---", "..."] and
    y.peek(3) in {' ', '\n', '\r', '\0'}

proc isDash*(y: YamlParseContext): bool =
  ## true if at a block sequence entry indicator
  y.hasChar and y.ch == '-' and y.peek(1) in {' ', '\n', '\r', '\0'}

proc atValueEnd*(y: YamlParseContext): bool =
  ## to be called after eatSpaceAndComments,
  ## true if there is no value to parse at current position (empty value)
  if not y.hasChar or y.isDocMarker:
    return true
  if y.flow > 0:
    return y.ch in {',', ']', '}'}
  if y.atLineStart and y.col <= y.ind:
    # a block sequence is allowed at the same indentation of its key
    return not (y.col == y.ind and y.owner == ownerKey and y.isDash)
  false

proc atScalarEnd(y: YamlParseContext, start: int): bool =
  ## true if a plain scalar (started at start) ends at current position
  let c = y.ch
  if c in lineBreaks:
    return true
  if c == ':' and (y.peek(1) in {' ', '\n', '\r', '\0'} or
      (y.flow > 0 and y.peek(1) in flowIndicators)):
    return true
  if c == '#' and y.idx > start and y.data[y.idx - 1] == ' ':
    return true
  if y.flow > 0 and c in flowIndicators:
    return true
  false

proc parsePlainLine(y: var YamlParseContext): string =
  ## parses a single line plain scalar (stripped of trailing whitespace)
  let start = y.idx
  while y.hasChar and not y.atScalarEnd(start):
    inc y
  y.data[start ..< y.idx].strip(leading = false, chars = {' ', '\t'})

proc parseSymbol*(y: var YamlParseContext): string =
  ## parses a single line plain scalar and returns it
  ## used for numbers, booleans and null
  discard y.eatSpaceAndComments
  if y.atValueEnd:
    y.error("Expected a value, found nothing.")
  if y.ch in {'"', '\''}:
    y.error("Expected a plain value, found a quoted string.")
  y.parsePlainLine

proc parsePlain(y: var YamlParseContext): string =
  ## parses a plain scalar which might span multiple lines
  result = y.parsePlainLine
  if y.flow > 0:
    return
  while true:
    # continuation lines must be more indented than the owner
    let save = y.idx
    if not y.hasChar or y.ch notin lineBreaks:
      break
    var breaks = 0
    while y.hasChar and y.ch in {' ', '\n', '\r'}:
      if y.ch == '\n' or (y.ch == '\r' and y.peek(1) != '\n'):
        inc breaks
      inc y
    if not y.hasChar or y.ch in {'#', '\t'} or y.col <= y.ind or y.isDocMarker or
        y.atScalarEnd(y.idx):
      y.idx = save
      break
    let next = y.parsePlainLine
    if breaks == 1:
      result.add ' '
    else:
      result.add '\n'.repeat(breaks - 1)
    result.add next

proc foldLineBreak(y: var YamlParseContext, s: var string, keep: int) =
  ## folds line breaks inside a quoted scalar:
  ## a single break becomes a space, n breaks become n-1 newlines.
  ## trailing whitespace (after position keep) is removed
  var i = s.len
  while i > keep and s[i - 1] in {' ', '\t'}:
    dec i
  s.setLen i
  var breaks = 0
  while y.hasChar and y.ch in {' ', '\t', '\n', '\r'}:
    if y.ch == '\n' or (y.ch == '\r' and y.peek(1) != '\n'):
      inc breaks
    inc y
  if breaks == 1:
    s.add ' '
  else:
    s.add '\n'.repeat(breaks - 1)

proc parseHexChar(y: var YamlParseContext, n: int): int =
  for _ in 1 .. n:
    inc y
    if not y.hasChar:
      y.error("Unterminated escape sequence.")
    let c = y.ch
    let d =
      case c
      of '0'..'9': ord(c) - ord('0')
      of 'a'..'f': ord(c) - ord('a') + 10
      of 'A'..'F': ord(c) - ord('A') + 10
      else:
        y.error("Invalid hex digit in escape sequence.")
    result = result * 16 + d

proc parseDoubleQuoted*(y: var YamlParseContext): string =
  ## parses a double quoted string (with escapes), current char must be `"`
  inc y
  var keep = 0 # escaped chars are not stripped when folding lines
  while true:
    if not y.hasChar:
      y.error("Unterminated double quoted string.")
    case y.ch
    of '"':
      inc y
      break
    of '\\':
      inc y
      if not y.hasChar:
        y.error("Unterminated double quoted string.")
      case y.ch
      of '0': result.add '\0'
      of 'a': result.add '\a'
      of 'b': result.add '\b'
      of 't', '\t': result.add '\t'
      of 'n': result.add '\n'
      of 'v': result.add '\v'
      of 'f': result.add '\f'
      of 'r': result.add '\r'
      of 'e': result.add '\e'
      of ' ': result.add ' '
      of '"': result.add '"'
      of '/': result.add '/'
      of '\\': result.add '\\'
      of 'N': result.add "\u0085"
      of '_': result.add " "
      of 'L': result.add " "
      of 'P': result.add " "
      of 'x': result.add chr(y.parseHexChar(2))
      of 'u': result.add toUTF8(Rune(y.parseHexChar(4)))
      of 'U': result.add toUTF8(Rune(y.parseHexChar(8)))
      of '\n', '\r':
        # escaped line break: lines are joined without space
        if y.ch == '\r' and y.peek(1) == '\n':
          inc y
        inc y
        while y.hasChar and y.ch in {' ', '\t'}:
          inc y
        keep = result.len
        continue
      else:
        y.error("Invalid escape sequence: \\" & y.ch)
      inc y
      keep = result.len
    of '\n', '\r':
      y.foldLineBreak(result, keep)
    else:
      result.add y.ch
      inc y

proc parseSingleQuoted*(y: var YamlParseContext): string =
  ## parses a single quoted string, current char must be `'`
  inc y
  while true:
    if not y.hasChar:
      y.error("Unterminated single quoted string.")
    case y.ch
    of '\'':
      if y.peek(1) == '\'':
        result.add '\''
        inc y.idx, 2
      else:
        inc y
        break
    of '\n', '\r':
      y.foldLineBreak(result, 0)
    else:
      result.add y.ch
      inc y

proc parseBlockScalar*(y: var YamlParseContext): string =
  ## parses a literal (`|`) or folded (`>`) block scalar
  let literal = y.ch == '|'
  inc y
  var
    chomp = ' ' # ' ' clip, '-' strip, '+' keep
    explicitInd = 0
  while y.hasChar:
    case y.ch
    of '-', '+':
      chomp = y.ch
    of '1'..'9':
      explicitInd = ord(y.ch) - ord('0')
    else:
      break
    inc y
  discard y.eatSpace
  if y.hasChar and y.ch == '#' and y.data[y.idx - 1] == ' ':
    while y.hasChar and y.ch notin lineBreaks:
      inc y
  if y.hasChar and y.ch notin lineBreaks:
    y.error("Unexpected content after block scalar indicator.")
  y.eatLine
  var
    contentInd = if explicitInd > 0: max(y.ind, 0) + explicitInd else: -1
    lines: seq[string]
  while y.hasChar:
    let lineStart = y.idx
    let sp = y.eatSpace
    if not y.hasChar or y.ch in lineBreaks:
      # empty line
      lines.add(if contentInd >= 0 and sp > contentInd: spaces(sp - contentInd) else: "")
      y.eatLine
      continue
    if contentInd < 0:
      contentInd = sp
    if sp < contentInd or sp <= y.ind or (sp == 0 and y.isDocMarker):
      y.idx = lineStart
      break
    let start = lineStart + contentInd
    y.eatLine
    var stop = y.idx
    while stop > start and y.data[stop - 1] in lineBreaks:
      dec stop
    lines.add y.data[start ..< stop]
  # separate trailing empty lines
  var last = lines.high
  while last >= 0 and lines[last].len == 0:
    dec last
  let trailing = lines.len - 1 - last
  if last < 0:
    return (if chomp == '+': '\n'.repeat(trailing) else: "")
  if literal:
    result = lines[0 .. last].join("\n")
  else:
    for i in 0 .. last:
      let l = lines[i]
      if i == 0:
        result.add l
      elif l.len == 0:
        result.add '\n'
      elif l[0] in {' ', '\t'} or lines[i - 1].len > 0 and lines[i - 1][0] in {' ', '\t'}:
        result.add '\n'
        result.add l
      elif lines[i - 1].len == 0:
        result.add l
      else:
        result.add ' '
        result.add l
  case chomp
  of '-': discard
  of '+': result.add '\n'.repeat(trailing + 1)
  else: result.add '\n'

proc parseHook*(y: var YamlParseContext, v: var string) =
  ## parses a string (plain, quoted or block scalar); an empty value gives ""
  discard y.eatSpaceAndComments
  if y.atValueEnd:
    v = ""
    return
  case y.ch
  of '"':
    v = y.parseDoubleQuoted
  of '\'':
    v = y.parseSingleQuoted
  of '|', '>':
    if y.flow > 0:
      y.error("Block scalars are not allowed inside flow collections.")
    v = y.parseBlockScalar
  of '[', '{':
    y.error("Expected a string, found a flow collection.")
  of '&', '*', '!', '%', '@', '`':
    y.error("Invalid start of a plain string: '" & y.ch & "' (anchors, aliases, tags and directives are not supported).")
  of '-', '?', ':':
    if y.peek(1) in {' ', '\n', '\r', '\0'}:
      y.error("Expected a string, found '" & y.ch & "' indicator.")
    v = y.parsePlain
  else:
    v = y.parsePlain

proc parseHook*(y: var YamlParseContext, v: var char) =
  ## parses a string made of a single char
  var s: string
  y.parseHook(s)
  if s.len != 1:
    y.error("Expected a single char, found: " & s)
  v = s[0]

proc parseIntLit(s: string, neg: var bool, mag: var BiggestUInt): bool =
  ## parses an integer literal (decimal, 0x hex, 0o octal, 0b binary, with optional _)
  var i = 0
  if i < s.len and s[i] in {'+', '-'}:
    neg = s[i] == '-'
    inc i
  var base = 10'u64
  if i + 1 < s.len and s[i] == '0' and s[i + 1] in {'x', 'X', 'o', 'O', 'b', 'B'}:
    base = case s[i + 1]
      of 'x', 'X': 16'u64
      of 'o', 'O': 8'u64
      else: 2'u64
    inc i, 2
  var any = false
  while i < s.len:
    let c = s[i]
    inc i
    if c == '_' and any:
      continue
    let d = case c
      of '0'..'9': BiggestUInt(ord(c) - ord('0'))
      of 'a'..'f': BiggestUInt(ord(c) - ord('a') + 10)
      of 'A'..'F': BiggestUInt(ord(c) - ord('A') + 10)
      else: return false
    if d >= base or mag > (high(BiggestUInt) - d) div base:
      return false
    mag = mag * base + d
    any = true
  any

proc parseHook*(y: var YamlParseContext, v: var SomeInteger) =
  ## parses an integer (decimal, 0x hex, 0o octal or 0b binary)
  let s = y.parseSymbol
  var
    neg = false
    mag: BiggestUInt
  if not parseIntLit(s, neg, mag):
    y.error("Invalid integer: " & s)
  when v is SomeUnsignedInt:
    if neg and mag > 0 or mag > BiggestUInt(high(typeof(v))):
      y.error("Integer out of range: " & s)
    v = typeof(v)(mag)
  else:
    if neg:
      if mag > BiggestUInt(high(BiggestInt)) + 1 or
          mag > BiggestUInt(-(low(typeof(v)).BiggestInt + 1)) + 1:
        y.error("Integer out of range: " & s)
      v = if mag == 0: typeof(v)(0) else: typeof(v)(-BiggestInt(mag - 1) - 1)
    else:
      if mag > BiggestUInt(high(typeof(v))):
        y.error("Integer out of range: " & s)
      v = typeof(v)(mag)

proc parseHook*(y: var YamlParseContext, v: var SomeFloat) =
  ## parses a float (also .inf, -.inf and .nan)
  let s = y.parseSymbol
  case s
  of ".inf", ".Inf", ".INF", "+.inf", "+.Inf", "+.INF":
    v = Inf
  of "-.inf", "-.Inf", "-.INF":
    v = NegInf
  of ".nan", ".NaN", ".NAN":
    v = NaN
  else:
    try:
      v = typeof(v)(parseFloat(s.replace("_", "")))
    except ValueError:
      y.error("Invalid float: " & s)

proc parseHook*(y: var YamlParseContext, v: var bool) =
  ## parses a bool, only true and false (also capitalized or uppercase) are valid
  let s = y.parseSymbol
  case s
  of "true", "True", "TRUE":
    v = true
  of "false", "False", "FALSE":
    v = false
  else:
    y.error("Invalid bool (expected true or false): " & s)

proc parseHook*[T: enum](y: var YamlParseContext, v: var T) =
  ## parses an enum from its name (style insensitive) or from its ordinal value
  var s: string
  y.parseHook(s)
  try:
    v = parseEnum[T](s)
  except ValueError:
    var
      neg = false
      mag: BiggestUInt
    if parseIntLit(s, neg, mag) and not neg and mag <= BiggestUInt(ord(high(T))) and
        mag >= BiggestUInt(max(ord(low(T)), 0)):
      v = T(mag)
    else:
      y.error("Invalid value for enum " & $T & ": " & s)

proc skipNull*(y: var YamlParseContext): bool =
  ## to be called after eatSpaceAndComments, consumes a null value
  ## (null, Null, NULL, ~ or an empty value) and returns true if found
  if y.atValueEnd:
    return true
  for n in ["null", "Null", "NULL", "~"]:
    if y.data.continuesWith(n, y.idx):
      let save = y.idx
      inc y.idx, n.len
      if not y.hasChar or y.atScalarEnd(save) or y.ch == ' ':
        discard y.eatSpace
        return true
      y.idx = save
  false

proc parseHook*[T](y: var YamlParseContext, v: var Option[T]) =
  ## parses an optional value, null or empty value gives none
  discard y.eatSpaceAndComments
  if y.skipNull:
    v = none(T)
  else:
    var x: T
    y.parseHook(x)
    v = some(x)

proc parseHook*[T: distinct](y: var YamlParseContext, v: var T) =
  ## parses a distinct type as its base type
  var x: distinctBase(T)
  y.parseHook(x)
  v = T(x)

proc fromYaml*[T](s: string, x: typedesc[T]): T =
  ## Takes yaml and outputs the object it represents.
  ## * Extra yaml fields are ignored.
  ## * Missing yaml fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var y = YamlParseContext(data: s, idx: 0, ind: -1, owner: ownerTop)
  y.parseHook(result)
  discard y.eatSpaceAndComments
  if y.hasChar:
    y.error("Unexpected content after value.")

when defined(release):
  {.pop.}
