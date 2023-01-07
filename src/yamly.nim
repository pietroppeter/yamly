import std / strutils

type
  YamlParseContext* = object
    data*: string
    idx*: int
    ind*: int
  YamlError* = object of ValueError
  YamlDumpContext* = object
    data*: string
    ind*: int

template error*(y: YamlParseContext, msg: string) =
  ## Shortcut to raise an exception.
  raise newException(YamlError, msg & " At offset: " & $y.idx)

template ch*(y: YamlParseContext): char = y.data[y.idx]

template hasChar*(y: YamlParseContext): bool = y.idx < y.data.len

template inc*(y: var YamlParseContext) = inc y.idx

template add*(y: var YamlDumpContext, s: string | char) = y.data.add s

template newLineAndIndent*(y: var YamlDumpContext) = y.add '\n' & ' '.repeat(y.ind)

template indent*(y: var YamlDumpContext, body: untyped) =
  inc y.ind, 2
  body
  dec y.ind, 2

template lastChar*(y: YamlDumpContext): char =
  assert y.data.len > 0
  y.data[y.data.high]

when defined(release):
  {.push checks: off, inline.}

proc eatSpace*(y: var YamlParseContext): int =
  ## consumes whitespace (only space, no tabs, no newline!)
  ## and returns how much it has eaten
  while y.ch == ' ':
    inc result
    inc y.idx

proc eatSpaceAndComments*(y: var YamlParseContext): int =
  ## eats away space and comments and returns final indentation
  result = y.ind
  var seenNewline = false
  while y.hasChar:
    case y.ch
    of ' ':
      if seenNewline:
        result = y.eatSpace
      else:
        discard y.eatSpace
    of '\n', '\r':
      inc y
      while y.ch in ['\n', '\r']:
        inc y
      seenNewline = true
    of '#':
      inc y
      while y.ch notIn ['\n', '\r']:
        inc y
    else:
      break

proc parseSymbol*(y: var YamlParseContext): string =
  ## parses a symbol and returns it
  ## used for numbers and booleans
  let ind = y.ind
  if y.eatSpaceAndComments < ind:
    y.error("Symbol appears before indentation")
  let idx = y.idx
  while y.hasChar:
    case y.ch
    of ' ', '\n', '\r', '\t', ',', '}', ']':
      break
    else:
      discard
    inc y
  return y.data[idx ..< y.idx]

proc parseHook*(y: var YamlParseContext, v: var SomeInteger) =
  ## parses an integer
  v = type(v)(parseInt(y.parseSymbol))

proc parseHook*(y: var YamlParseContext, v: var SomeFloat) =
  ## parses a float
  v = type(v)(parseFloat(y.parseSymbol))

proc fromYaml*[T](s: string, x: typedesc[T]): T =
  ## Takes yaml and outputs the object it represents.
  ## * Extra yaml fields are ignored.
  ## * Missing yaml fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var y = YamlParseContext(data: s, idx: 0, ind: 0)
  y.parseHook(result)

proc dumpHook*(y: var YamlDumpContext, v: SomeNumber) =
  if y.ind > 0:
    y.add ' '
  y.add $v

proc dumpHook*[T](y: var YamlDumpContext, a: openarray[T]) =
  if a.len == 0:
    y.add " []"
    return
  var i = 0
  if y.ind > 0:
    y.newLineAndIndent
  for v in a:
    if i > 0:
      y.newLineAndIndent
    y.add "-"
    y.indent:
      y.dumpHook(v)
    inc i

template dumpKey(y: var YamlDumpContext, v: string) =
  const v2 = $v & ':'
  y.add v2

proc dumpHook*(y: var YamlDumpContext, v: object) =
  var i = 0
  if y.ind > 0:
    if y.lastChar == ':':
      y.newLineAndIndent
    else:
      y.add ' '
  when compiles(for k, e in v.pairs: discard):
    # Tables and table like objects. TODO
    for k, e in v.pairs:
      if i > 0:
        y.newLineAndIndent
      y.dumpHook(k) # likely needs to change
      y.add ':'
      y.indent:
        y.dumpHook(e)
      inc i
  else:
    # Normal objects.
    for k, e in v.fieldPairs:
      if i > 0:
        y.newLineAndIndent
      y.dumpKey(k)
      y.indent:
        y.dumpHook(e)
      inc i

proc toYaml*[T](v: T): string =
  var y = YamlDumpContext(data: "", ind: 0)
  y.dumpHook(v)
  y.data

when defined(release):
  {.pop.}