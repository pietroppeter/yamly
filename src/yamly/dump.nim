import std / [strutils, options, typetraits, math]

type
  YamlDumpContext* = object
    data*: string
    ind*: int

template add*(y: var YamlDumpContext, s: string | char) = y.data.add s

template newLineAndIndent*(y: var YamlDumpContext) = y.add '\n' & ' '.repeat(y.ind)

template indent*(y: var YamlDumpContext, body: untyped) =
  inc y.ind, 2
  body
  dec y.ind, 2

template lastChar*(y: YamlDumpContext): char =
  assert y.data.len > 0
  y.data[y.data.high]

template sep*(y: var YamlDumpContext) =
  ## separates a scalar value from its key or dash
  if y.ind > 0:
    y.add ' '

when defined(release):
  {.push checks: off, inline.}

const
  reservedWords = ["true", "false", "yes", "no", "on", "off", "y", "n",
    "null", "~", ".inf", "+.inf", "-.inf", ".nan", "<<", "=", "-", "?", ":"]
  indicators = {'-', '?', ':', ',', '[', ']', '{', '}', '#', '&', '*', '!',
    '|', '>', '\'', '"', '%', '@', '`'}

proc needsQuotes*(s: string): bool =
  ## true if string cannot be dumped as a plain scalar,
  ## either because it would not be valid yaml or because a yaml parser
  ## (1.1 or 1.2) could read it as something which is not a string
  if s.len == 0 or s[0] in indicators or s[0] in {' ', '\t'} or s[^1] in {' ', '\t', ':'}:
    return true
  if s.toLowerAscii in reservedWords:
    return true
  # anything which looks like a number (also sexagesimal 1:20 or version 1.10)
  if s[0] in Digits or s[0] in {'+', '.'} and s.len > 1 and s[1] in Digits or
      s.len > 1 and s[0] == '+' and s[1] == '.':
    return true
  for i, c in s:
    if c < ' ' or c == '\x7F':
      return true
    if c == ':' and i + 1 < s.len and s[i + 1] == ' ':
      return true
    if c == '#' and i > 0 and s[i - 1] == ' ':
      return true
  false

proc dumpDoubleQuoted*(y: var YamlDumpContext, s: string) =
  ## dumps a double quoted string escaping as needed
  y.add '"'
  for c in s:
    case c
    of '"': y.add "\\\""
    of '\\': y.add "\\\\"
    of '\n': y.add "\\n"
    of '\t': y.add "\\t"
    of '\r': y.add "\\r"
    of '\0': y.add "\\0"
    of '\x01'..'\x08', '\x0B', '\x0C', '\x0E'..'\x1F', '\x7F':
      y.add "\\x" & toHex(ord(c), 2)
    else: y.add c
  y.add '"'

proc canDumpLiteral(s: string): bool =
  ## true if a multi line string can be dumped as a literal block scalar
  if '\n' notin s or s.strip(chars = {'\n'}).len == 0 or s.endsWith("\n\n") or
      s[0] in {' ', '\t'}:
    return false
  for line in s.split('\n'):
    if line.len > 0 and line.strip(chars = {' '}).len == 0:
      return false
    for c in line:
      if c < ' ' and c != '\t' or c == '\x7F':
        return false
  true

proc dumpLiteral(y: var YamlDumpContext, s: string) =
  ## dumps a multi line string as a literal block scalar (`|`)
  let content = if s.endsWith('\n'): s[0 .. ^2] else: s
  y.add(if s.endsWith('\n'): "|" else: "|-")
  let ind = if y.ind > 0: y.ind else: 2
  for line in content.split('\n'):
    y.add '\n'
    if line.len > 0:
      y.add ' '.repeat(ind)
      y.add line

proc dumpHook*(y: var YamlDumpContext, v: string) =
  ## dumps a string as plain, double quoted or literal block scalar
  y.sep
  if canDumpLiteral(v):
    y.dumpLiteral(v)
  elif needsQuotes(v):
    y.dumpDoubleQuoted(v)
  else:
    y.add v

proc dumpHook*(y: var YamlDumpContext, v: char) =
  y.dumpHook($v)

proc dumpHook*(y: var YamlDumpContext, v: bool) =
  y.sep
  y.add(if v: "true" else: "false")

proc dumpHook*(y: var YamlDumpContext, v: SomeInteger) =
  y.sep
  y.add $v

proc dumpHook*(y: var YamlDumpContext, v: SomeFloat) =
  y.sep
  case classify(v)
  of fcInf: y.add ".inf"
  of fcNegInf: y.add "-.inf"
  of fcNan: y.add ".nan"
  else: y.add $v

proc dumpHook*[T: enum](y: var YamlDumpContext, v: T) =
  y.dumpHook($v)

proc dumpHook*[T](y: var YamlDumpContext, v: Option[T]) =
  if v.isSome:
    y.dumpHook(v.get)
  else:
    y.sep
    y.add "null"

proc dumpHook*[T: distinct](y: var YamlDumpContext, v: T) =
  y.dumpHook(distinctBase(T)(v))

proc dumpHook*[T](y: var YamlDumpContext, a: openarray[T]) =
  if a.len == 0:
    y.sep
    y.add "[]"
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
