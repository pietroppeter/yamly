import yamly, std / unittest

suite "numbers":
  test "dump numbers":
    check toYaml(1) == "1"
    check toYaml(3.14) == "3.14"
    check toYaml(-1) == "-1"
    check toYaml(-0.1) == "-0.1"

  test "parse numbers":
    check "1".fromYaml(int) == 1
    check "3.14".fromYaml(float) == 3.14
    check "  -1".fromYaml(int) == -1
    check "  \n  Inf".fromYaml(float) == Inf
    check "  \n  # comment\n  0 # another".fromYaml(float) == 0.0
    check "1".fromYaml(int8) == 1.int8
    check "1".fromYaml(uint8) == 1.uint8
    check "3.14".fromYaml(float32) == 3.14.float32
    check "10_000".fromYaml(int) == 10_000

suite "errors":
  test "parsing errors":
    expect(ValueError):
      discard "a".fromYaml(int)

  test "not valid yaml":
    let s = """
a:
  b:
 1
"""
    var idx = 7
    var v: int
    expect(YamlError):
      parseHook(s, idx, 2, v)

suite "eatUtils":
  test "eatSpaceAndComments":
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
    check v == 1

suite "sequences":
  test "dump sequences":
    let a = @[1, 2, 3]
    check a.toYaml == """
- 1
- 2
- 3"""

    let aa = @[@[1.0, 2.0], @[3.0, 4.0]]
    check aa.toYaml == """
-
  - 1.0
  - 2.0
-
  - 3.0
  - 4.0"""

suite "objects":

  test "dump objects":
    type Obj = object
      a: int
      b: float
    
    let o = Obj(a: 1, b: 1.5)
    check o.toYaml == """
a: 1
b: 1.5"""

    type ObjObj = object
      c: float
      d: Obj
      e: int

    let oo = ObjObj(c:0.5, d: o, e: 2)
    check oo.toYaml == """
c: 0.5
d:
  a: 1
  b: 1.5
e: 2"""

    type ObjObjObj = object
      g: Obj
      h: ObjObj

    let ooo = ObjObjObj(g: o, h: oo)
    check ooo.toYaml == """
g:
  a: 1
  b: 1.5
h:
  c: 0.5
  d:
    a: 1
    b: 1.5
  e: 2"""

    let so = @[
      Obj(a:1, b:1.0),
      Obj(a:2, b:2.0),
    ]
    check so.toYaml == """
- a: 1
  b: 1.0
- a: 2
  b: 2.0"""

    type ObjSeq = object
      vals: seq[int]

    let os = ObjSeq(vals: @[1, 2, 3])
    check os.toYaml == """
vals:
  - 1
  - 2
  - 3"""