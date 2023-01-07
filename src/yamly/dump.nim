import std / strutils

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

when defined(release):
  {.push checks: off, inline.}

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