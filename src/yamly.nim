import std / strutils

type
  YamlParseContext* = object
    data*: string
    idx*: int
    ind*: int
  YamlError* = object of ValueError

template error*(y: YamlParseContext, msg: string) =
  ## Shortcut to raise an exception.
  raise newException(YamlError, msg & " At offset: " & $y.idx)

template ch*(y: YamlParseContext): char = y.data[y.idx]

template hasChar*(y: YamlParseContext): bool = y.idx < y.data.len

template inc*(y: var YamlParseContext) = inc y.idx

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

proc dumpHook*(s: var string, ind: int, v: SomeNumber) =
  if ind > 0:
    s.add ' '
  s.add $v

proc dumpHook*[T](s: var string, ind: var int, a: openarray[T]) =
  if a.len == 0:
    s.add " []"
    return
  var i = 0
  if ind > 0:
    s.add '\n' & ' '.repeat(ind)
  for v in a:
    if i > 0:
      s.add '\n' & ' '.repeat(ind)
    s.add "-"
    ind.inc 2
    s.dumpHook(ind, v)
    ind.dec 2
    inc i

template dumpKey(s: var string, v: string) =
  const v2 = $v & ':'
  s.add v2

proc dumpHook*(s: var string, ind: var int, v: object) =
  var i = 0
  if ind > 0:
    if s[^1] == ':':
      s.add '\n' & ' '.repeat(ind)
    else:
      s.add ' '
  when compiles(for k, e in v.pairs: discard):
    # Tables and table like objects. TODO
    for k, e in v.pairs:
      if i > 0:
        s.add '\n' & ' '.repeat(ind)
      s.dumpHook(ind, k) # likely needs to change
      s.add ':'
      ind.inc 2
      s.dumpHook(ind, e)
      ind.dec 2
      inc i
  else:
    # Normal objects.
    for k, e in v.fieldPairs:
      if i > 0:
        s.add '\n' & ' '.repeat(ind)
      s.dumpKey(k)
      ind.inc 2
      s.dumpHook(ind, e)
      ind.dec 2
      inc i

proc toYaml*[T](v: T): string =
  var ind = 0
  dumpHook(result, ind, v)

when defined(release):
  {.pop.}