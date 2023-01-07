import yamly, std / unittest

suite "dump symbols":
  test "numbers":
    check toYaml(1) == "1"
    check toYaml(3.14) == "3.14"
    check toYaml(-1) == "-1"
    check toYaml(-0.1) == "-0.1"

suite "dump containers":
  test "sequences":
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

    let ar = @[[1.0, 2.0], [3.0, 4.0]]
    check ar.toYaml == """
-
  - 1.0
  - 2.0
-
  - 3.0
  - 4.0"""
  test "objects":
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

  test "objects and sequences":
    type Obj = object
      a: int
      b: float

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

    let osEmpty = ObjSeq(vals: @[])
    check osEmpty.toYaml == """
vals: []"""