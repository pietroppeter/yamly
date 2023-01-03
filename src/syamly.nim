import std / strutils

type YamlError* = object of ValueError

when defined(release):
  {.push checks: off, inline.}


template error(msg: string, idx: int) =
  ## Shortcut to raise an exception.
  raise newException(YamlError, msg & " At offset: " & $idx)


proc eatSpace*(s: string, idx: var int): int =
  ## consumes whitespace (only space, no tabs, no newline!)
  ## and returns how much it has eaten
  while s[idx] == ' ':
    inc result
    inc idx

proc eatSpaceAndComments*(s: string, idx: var int, ind: int): int =
  ## eats away space and comments and returns final indentation
  result = ind
  var seenNewline = false
  while idx < s.len:
    let c = s[idx]
    case c
    of ' ':
      if seenNewline:
        result = eatSpace(s, idx)
      else:
        discard eatSpace(s, idx)
    of '\n', '\r':
      inc idx
      while s[idx] in ['\n', '\r']:
        inc idx
      seenNewline = true
    of '#':
      inc idx
      while s[idx] notIn ['\n', '\r']:
        inc idx
    else:
      break


proc parseSymbol*(s: string; idx: var int, ind: int): string =
  ## parses a symbol and returns it
  ## used for numbers and booleans
  if eatSpaceAndComments(s, idx, ind) < ind:
    error("Symbol appears before indentation", idx)
  let j = idx
  while idx < s.len:
    case s[idx]
    of ' ', '\n', '\r', '\t', ',', '}', ']':
      break
    else:
      discard
    inc idx
  return s[j ..< idx]

proc parseHook*(s: string; idx: var int, ind: int, v: var SomeInteger) =
  ## parses an integer
  v = type(v)(parseInt(parseSymbol(s, idx, ind)))

proc parseHook*(s: string; idx: var int, ind: int, v: var SomeFloat) =
  ## parses a float
  v = type(v)(parseFloat(parseSymbol(s, idx, ind)))

proc fromYaml*[T](s: string, x: typedesc[T]): T =
  ## Takes yaml and outputs the object it represents.
  ## * Extra yaml fields are ignored.
  ## * Missing yaml fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var
    idx = 0
    ind = 0
  s.parseHook(idx, ind, result)

proc dumpHook*(s: var string, v: SomeNumber) =
  s.add $v


proc toYaml*[T](v: T): string =
  dumpHook(result, v)

when defined(release):
  {.pop.}