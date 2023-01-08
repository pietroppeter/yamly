
import yamly, std / unittest

suite "parse symbols":
  test "numbers":
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
    var y = YamlParseContext(data: s, idx: 7, ind:2)
    var v: int
    expect(YamlError):
      y.parseHook(v)

    block:
      let s = """
a:
  b:
  1
"""
      var y = YamlParseContext(data: s, idx: 7, ind:2)
      var v: int
      expect(YamlError):
        y.parseHook(v)

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
    var y = YamlParseContext(data: s, idx: 7, ind:2)
    var v: int
    y.parseHook(v)
    check v == 1

