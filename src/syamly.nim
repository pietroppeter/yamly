type YamlError* = object of ValueError

const whiteSpace = {' ', '\n', '\t', '\r'}

when defined(release):
  {.push checks: off, inline.}


proc fromYaml*[T](s: string, x: typedesc[T]): T =
  ## Takes yaml and outputs the object it represents.
  ## * Extra yaml fields are ignored.
  ## * Missing yaml fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var i = 0
  s.parseHook(i, result)

proc dumpHook*(s: var string, v: SomeNumber) =
  s.add $v


proc toYaml*[T](v: T): string =
  dumpHook(result, v)

when defined(release):
  {.pop.}