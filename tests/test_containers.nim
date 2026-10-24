import yamly, std / [unittest, options, tables, sets, json, strutils]

type
  Color = enum
    red, green, blue
  Obj = object
    a: int
    b: string
  Nested = object
    name: string
    obj: Obj
    list: seq[Obj]
    nums: seq[int]
  Node = ref object
    value: int
    next: Node
  Settings = object
    userName: string
    maxRetries: int
  ShapeKind = enum
    circle, rect
  Shape = object
    name: string
    case kind: ShapeKind
    of circle:
      radius: float
    of rect:
      width, height: float
  WithHooks = object
    x: int
    y: int
    sum: int
    internal: string

proc newHook(v: var WithHooks) =
  v.y = 10

proc postHook(v: var WithHooks) =
  v.sum = v.x + v.y

proc renameHook(v: var WithHooks, key: var string) =
  if key == "ex":
    key = "x"

proc skipHook(T: typedesc[WithHooks], key: static string): bool =
  key == "internal"

suite "parse block sequences":
  test "simple":
    check "- 1\n- 2\n- 3".fromYaml(seq[int]) == @[1, 2, 3]
    check "- a\n- b c\n- 'd'".fromYaml(seq[string]) == @["a", "b c", "d"]
    check "# comment\n- 1 # one\n\n- 2\n".fromYaml(seq[int]) == @[1, 2]

  test "nested":
    check "- - 1\n  - 2\n- - 3".fromYaml(seq[seq[int]]) == @[@[1, 2], @[3]]
    check "-\n  - 1\n  - 2\n-\n  - 3".fromYaml(seq[seq[int]]) == @[@[1, 2], @[3]]

  test "empty":
    check "".fromYaml(seq[int]).len == 0
    check "[]".fromYaml(seq[int]).len == 0
    check "null".fromYaml(seq[int]).len == 0

  test "arrays, sets and tuples":
    check "- 1\n- 2".fromYaml(array[3, int]) == [1, 2, 0]
    check "- red\n- blue\n- red".fromYaml(set[Color]) == {red, blue}
    check "- a\n- b\n- a".fromYaml(HashSet[string]) == toHashSet(["a", "b"])
    check "- a\n- b".fromYaml(OrderedSet[string]) == toOrderedSet(["a", "b"])
    check "- 1\n- x".fromYaml((int, string)) == (1, "x")
    check "a: 1\nb: x".fromYaml(tuple[a: int, b: string]) == (a: 1, b: "x")
    expect(YamlError):
      discard "- 1\n- 2\n- 3".fromYaml(array[2, int])
    expect(YamlError):
      discard "- 1\n- x\n- 3".fromYaml((int, string))

  test "invalid":
    for s in ["- 1\n  - 2", "- 1\n - 2", "- 1 - 2", "1\n- 2", "- 1\n2"]:
      expect(YamlError):
        discard s.fromYaml(seq[int])

suite "parse block mappings":
  test "objects":
    check "a: 1\nb: x".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "b: x\na: 1".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "a: 1".fromYaml(Obj) == Obj(a: 1)
    check "a: 1\nunknown:\n  deep: [1, {x: 2}]\n  more:\n    - no\nb: x".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "  a: 1\n  b: x\n".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "a:    1   # comment\n# comment\nb:  x".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "\"a\": 1\n'b': x".fromYaml(Obj) == Obj(a: 1, b: "x")

  test "nested":
    let s = """
name: test
obj:
  a: 1
  b: one
list:
  - a: 2
    b: two
  -
    a: 3
nums:
- 1
- 2
"""
    check s.fromYaml(Nested) == Nested(name: "test", obj: Obj(a: 1, b: "one"),
      list: @[Obj(a: 2, b: "two"), Obj(a: 3)], nums: @[1, 2])

  test "empty values":
    check "a: 1\nb:".fromYaml(Obj) == Obj(a: 1)
    expect(YamlError): # an empty value is not a valid int
      discard "a:\nb: x".fromYaml(Obj)
    check "name: x\nobj:\nnums:".fromYaml(Nested) == Nested(name: "x")

  test "style insensitive keys":
    check "user_name: x\nmax-retries: 3".fromYaml(Settings) == Settings(userName: "x", maxRetries: 3)
    check "userName: x\nmaxRetries: 3".fromYaml(Settings) == Settings(userName: "x", maxRetries: 3)

  test "hooks":
    check "x: 1".fromYaml(WithHooks) == WithHooks(x: 1, y: 10, sum: 11)
    check "ex: 2\ny: 3".fromYaml(WithHooks) == WithHooks(x: 2, y: 3, sum: 5)

  test "object variants":
    let c = "name: c\nkind: circle\nradius: 2".fromYaml(Shape)
    check c.kind == circle
    check c.name == "c"
    check c.radius == 2.0
    let r = "kind: rect\nwidth: 1\nheight: 2\nname: r".fromYaml(Shape)
    check r.kind == rect
    check r.name == "r"
    check r.width == 1.0
    check r.height == 2.0
    let s = Shape(name: "s", kind: rect, width: 3, height: 4)
    check s.toYaml == "name: s\nkind: rect\nwidth: 3.0\nheight: 4.0"
    check s.toYaml.fromYaml(Shape).height == 4.0

  test "refs":
    let n = "value: 1\nnext:\n  value: 2\n  next: null".fromYaml(Node)
    check n.value == 1
    check n.next.value == 2
    check n.next.next == nil
    check "null".fromYaml(Node) == nil

  test "tables":
    check "a: 1\nb: 2".fromYaml(Table[string, int]) == {"a": 1, "b": 2}.toTable
    check "b: 1\na: 2".fromYaml(OrderedTable[string, int]) == {"b": 1, "a": 2}.toOrderedTable
    check "1: a\n0x10: b".fromYaml(Table[int, string]) == {1: "a", 16: "b"}.toTable
    check "red: 1\nblue: 2".fromYaml(Table[Color, int]) == {red: 1, blue: 2}.toTable
    check "x:\n  - 1\ny: []".fromYaml(TableRef[string, seq[int]])[] == {"x": @[1], "y": newSeq[int]()}.toTable
    check "null: 1\n~: 2".fromYaml(Table[string, int]) == {"null": 1, "~": 2}.toTable
    expect(YamlError):
      discard "x: 1".fromYaml(Table[int, int])

  test "invalid":
    for s in ["a: 1\n b: x", "a: 1\n  b: x", "a: b: 1", "a: 1 b: x", "a 1",
        "? a\n: 1", "&x a: 1", "a: 1\n- 2"]:
      expect(YamlError):
        discard s.fromYaml(Obj)
    expect(YamlError):
      discard "obj: a: 1".fromYaml(Nested)
    expect(YamlError):
      discard "nums: - 1".fromYaml(Nested)

suite "parse flow style":
  test "sequences":
    check "[1, 2, 3]".fromYaml(seq[int]) == @[1, 2, 3]
    check "[1, 2, 3,]".fromYaml(seq[int]) == @[1, 2, 3]
    check "[ a b , 'c, d', \"e]\" ]".fromYaml(seq[string]) == @["a b", "c, d", "e]"]
    check "[[1, 2], [], [3]]".fromYaml(seq[seq[int]]) == @[@[1, 2], @[], @[3]]
    check "[\n  1,\n  # comment\n  2\n]".fromYaml(seq[int]) == @[1, 2]

  test "mappings":
    check "{a: 1, b: x}".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "{\"a\":1,\"b\":\"x\"}".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "{a: 1, b: [x, {y: z}]}".fromYaml(JsonNode) == %*{"a": 1, "b": ["x", {"y": "z"}]}
    check "{}".fromYaml(Table[string, int]).len == 0
    check "obj: {a: 1}\nlist: [{a: 2}, {b: y}]".fromYaml(Nested) ==
      Nested(obj: Obj(a: 1), list: @[Obj(a: 2), Obj(b: "y")])

  test "invalid":
    for s in ["[1, 2", "[1 2]", "[1, - 2]", "[|\n 1]"]:
      expect(YamlError):
        discard s.fromYaml(seq[int])
    for s in ["{a: 1", "{a 1}", "{a: 1 b: 2}", "{a: {b: 1\nc: 2}"]:
      expect(YamlError):
        discard s.fromYaml(JsonNode)

suite "parse JsonNode":
  test "scalars":
    check "1".fromYaml(JsonNode) == %1
    check "-0x10".fromYaml(JsonNode) == %(-16)
    check "1.5".fromYaml(JsonNode) == %1.5
    check "1e3".fromYaml(JsonNode) == %1000.0
    check "true".fromYaml(JsonNode) == %true
    check "null".fromYaml(JsonNode).kind == JNull
    check "".fromYaml(JsonNode).kind == JNull
    for s in ["no", "yes", "on", "1.10.1", "22:22", "1_000", "'1'", "\"true\"", "0.1.2", "+", "-a"]:
      check s.fromYaml(JsonNode).kind == JString

  test "containers":
    let s = """
name: yamly
version: 0.1.0
tags: [yaml, nim]
deps:
  - name: std
    optional: false
  - name: unittest
empty:
nested:
  a:
    b: 1
"""
    check s.fromYaml(JsonNode) == %*{"name": "yamly", "version": "0.1.0",
      "tags": ["yaml", "nim"], "deps": [{"name": "std", "optional": false},
      {"name": "unittest"}], "empty": nil, "nested": {"a": {"b": 1}}}

suite "documents":
  test "markers":
    check "---\na: 1\nb: x\n...\n".fromYaml(Obj) == Obj(a: 1, b: "x")
    check "--- # comment\n- 1".fromYaml(seq[int]) == @[1]
    check "--- 1".fromYaml(int) == 1
    expect(YamlError):
      discard "a: 1\n---\na: 2".fromYaml(Obj)

suite "dump containers":
  test "nested":
    let n = Nested(name: "test", obj: Obj(a: 1, b: "one"),
      list: @[Obj(a: 2, b: "two"), Obj(a: 3)], nums: @[])
    check n.toYaml == """
name: test
obj:
  a: 1
  b: one
list:
  - a: 2
    b: two
  - a: 3
    b: ""
nums: []"""
    check n.toYaml.fromYaml(Nested) == n

  test "tables, sets and tuples":
    check {"a": 1, "no": 2, "x y": 3}.toOrderedTable.toYaml == "a: 1\n\"no\": 2\nx y: 3"
    check {1: "a", 2: "b"}.toOrderedTable.toYaml == "1: a\n2: b"
    check {red: @[1], blue: @[]}.toOrderedTable.toYaml == "red:\n  - 1\nblue: []"
    check initTable[string, int]().toYaml == "{}"
    check Obj(a: 1).toYaml.fromYaml(Obj) == Obj(a: 1)
    check {red, blue}.toYaml == "- red\n- blue"
    check (1, "x").toYaml == "- 1\n- x"
    check (a: 1, b: "x").toYaml == "a: 1\nb: x"
    check @[(a: 1, b: "x")].toYaml == "- a: 1\n  b: x"

  test "multi line strings in containers":
    let o = Obj(a: 1, b: "line 1\nline 2\n")
    check o.toYaml == "a: 1\nb: |\n  line 1\n  line 2"
    check o.toYaml.fromYaml(Obj) == o
    check @["x\ny"].toYaml == "- |-\n  x\n  y"
    check @["x\ny"].toYaml.fromYaml(seq[string]) == @["x\ny"]

  test "refs and hooks":
    check Node(value: 1).toYaml == "value: 1\nnext: null"
    check WithHooks(x: 1, internal: "secret").toYaml == "x: 1\n\"y\": 0\nsum: 0"

  test "keys that need quotes":
    type Weird = object
      y: int
      on: bool
    check Weird(y: 1, on: true).toYaml == "\"y\": 1\n\"on\": true"
    check Weird(y: 1, on: true).toYaml.fromYaml(Weird) == Weird(y: 1, on: true)

  test "JsonNode":
    let j = %*{"a": [1, 2.5, "no", nil, true], "b": {}, "c": {"d": "x\ny"}}
    check j.toYaml == "a:\n  - 1\n  - 2.5\n  - \"no\"\n  - null\n  - true\nb: {}\nc:\n  d: |-\n    x\n    y"
    check j.toYaml.fromYaml(JsonNode) == j
