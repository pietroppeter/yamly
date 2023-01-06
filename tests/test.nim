import syamly

block:
  # dump numbers
  doAssert toYaml(1) == "1"
  doAssert toYaml(3.14) == "3.14"
  doAssert toYaml(-1) == "-1"
  doAssert toYaml(-0.1) == "-0.1"

block:
  # parse numbers
  doAssert "1".fromYaml(int) == 1
  doAssert "3.14".fromYaml(float) == 3.14
  doAssert "  -1".fromYaml(int) == -1
  doAssert "  \n  Inf".fromYaml(float) == Inf
  doAssert "  \n  # comment\n  0 # another".fromYaml(float) == 0.0
  doAssert "1".fromYaml(int8) == 1.int8
  doAssert "1".fromYaml(uint8) == 1.uint8
  doAssert "3.14".fromYaml(float32) == 3.14.float32
  doAssert "10_000".fromYaml(int) == 10_000

block:
  # parsing error
  doAssertRaises(ValueError):
    discard "a".fromYaml(int)

block:
  # not valid yaml
  let s = """
a:
  b:
 1
"""
  var idx = 7
  var v: int
  doAssertRaises(YamlError):
    parseHook(s, idx, 2, v)

block:
  # valid yaml
  let s = """
a:
  b: # comment
# comment
  # comment
     # comment
   1
"""
  var idx = 7
  var v: int
  parseHook(s, idx, 2, v)
  doAssert v == 1

block:
  # dump objects
  type Obj = object
    a: int
    b: float
  
  let o = Obj(a: 1, b: 1.5)
  doAssert o.toYaml == """
a: 1
b: 1.5
"""

  type ObjObj = object
    c: int
    d: Obj
  
  let oo = ObjObj(c:2, d: o)
  doAssert oo.toYaml == """
c: 2
d:
  a: 1
  b: 1.5
"""
