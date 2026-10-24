import yamly, std / [unittest, options, math, strutils]

type
  Color = enum
    red, green, darkBlue
  Meters = distinct float

suite "parse scalars":
  test "integers":
    check "0x1F".fromYaml(int) == 31
    check "0o17".fromYaml(int) == 15
    check "0b101".fromYaml(int) == 5
    check "-0x10".fromYaml(int) == -16
    check "+42".fromYaml(int) == 42
    check "255".fromYaml(uint8) == 255'u8
    check "-128".fromYaml(int8) == -128'i8
    check "-9223372036854775808".fromYaml(int64) == low(int64)
    check "18446744073709551615".fromYaml(uint64) == high(uint64)
    expect(YamlError):
      discard "256".fromYaml(uint8)
    expect(YamlError):
      discard "-129".fromYaml(int8)
    expect(YamlError):
      discard "-1".fromYaml(uint)
    expect(YamlError):
      discard "1.5".fromYaml(int)
    expect(YamlError):
      discard "'1'".fromYaml(int)
    expect(YamlError):
      discard "".fromYaml(int)

  test "floats":
    check ".inf".fromYaml(float) == Inf
    check "-.inf".fromYaml(float) == NegInf
    check ".nan".fromYaml(float).isNaN
    check "1e3".fromYaml(float) == 1000.0
    check "2".fromYaml(float) == 2.0
    expect(YamlError):
      discard "abc".fromYaml(float)

  test "bools":
    check "true".fromYaml(bool) == true
    check "False".fromYaml(bool) == false
    check "TRUE # comment".fromYaml(bool) == true
    for s in ["yes", "no", "on", "off", "y", "n", "1"]:
      expect(YamlError):
        discard s.fromYaml(bool)

  test "enums":
    check "green".fromYaml(Color) == green
    check "dark_blue".fromYaml(Color) == darkBlue
    check "'red'".fromYaml(Color) == red
    check "1".fromYaml(Color) == green
    expect(YamlError):
      discard "purple".fromYaml(Color)
    expect(YamlError):
      discard "3".fromYaml(Color)

  test "distinct":
    check "1.5".fromYaml(Meters).float == 1.5

  test "chars":
    check "a".fromYaml(char) == 'a'
    check "'\"'".fromYaml(char) == '"'
    expect(YamlError):
      discard "ab".fromYaml(char)

  test "options":
    check "null".fromYaml(Option[int]) == none(int)
    check "~".fromYaml(Option[int]) == none(int)
    check "".fromYaml(Option[int]) == none(int)
    check "1".fromYaml(Option[int]) == some(1)
    check "null".fromYaml(Option[string]) == none(string)
    check "'null'".fromYaml(Option[string]) == some("null")
    check "nullable".fromYaml(Option[string]) == some("nullable")

suite "parse strings":
  test "plain":
    check "hello world".fromYaml(string) == "hello world"
    check "  hello  # comment".fromYaml(string) == "hello"
    check "a#b".fromYaml(string) == "a#b"
    check "a:b".fromYaml(string) == "a:b"
    check "http://example.com".fromYaml(string) == "http://example.com"
    check "".fromYaml(string) == ""

  test "no implicit typing":
    check "no".fromYaml(string) == "no"
    check "1.10".fromYaml(string) == "1.10"
    check "22:22".fromYaml(string) == "22:22"
    check "null".fromYaml(string) == "null"
    check "true".fromYaml(string) == "true"

  test "plain multi line":
    check "hello\n world\n\n again".fromYaml(string) == "hello world\nagain"

  test "double quoted":
    check "\"a \\\"b\\\" c\"".fromYaml(string) == "a \"b\" c"
    check "\"tab\\tnew\\nline\"".fromYaml(string) == "tab\tnew\nline"
    check "\"\\x41\\u00e8\\U0001F600\"".fromYaml(string) == "Aè😀"
    check "\"# not a comment\"".fromYaml(string) == "# not a comment"
    check "\"folded\n  line\n\n  break\"".fromYaml(string) == "folded line\nbreak"
    check "\"joined\\\n  line\"".fromYaml(string) == "joinedline"
    expect(YamlError):
      discard "\"unterminated".fromYaml(string)
    expect(YamlError):
      discard "\"bad \\q\"".fromYaml(string)

  test "single quoted":
    check "'it''s'".fromYaml(string) == "it's"
    check "'no \\ escapes'".fromYaml(string) == "no \\ escapes"
    check "'folded\n line'".fromYaml(string) == "folded line"

  test "literal block":
    check "|\n  a\n  b\n".fromYaml(string) == "a\nb\n"
    check "|-\n  a\n   b\n".fromYaml(string) == "a\n b"
    check "|+\n  a\n\n\n".fromYaml(string) == "a\n\n\n"
    check "|\n  a\n\n  b\n\n".fromYaml(string) == "a\n\nb\n"
    check "| # comment\n  a".fromYaml(string) == "a\n"
    check "|2\n   a\n".fromYaml(string) == " a\n"

  test "folded block":
    check ">\n  a\n  b\n\n  c\n".fromYaml(string) == "a b\nc\n"
    check ">-\n  a\n    b\n  c\n".fromYaml(string) == "a\n  b\nc"

  test "invalid":
    for s in ["&anchor", "*alias", "!tag x", "- a", "[a]", "{a: 1}", "@x", "a: b"]:
      expect(YamlError):
        discard s.fromYaml(string)

  test "tabs are not whitespace":
    expect(YamlError):
      discard "\t1".fromYaml(int)

suite "dump scalars":
  test "bools and enums":
    check true.toYaml == "true"
    check false.toYaml == "false"
    check darkBlue.toYaml == "darkBlue"

  test "floats":
    check Inf.toYaml == ".inf"
    check NegInf.toYaml == "-.inf"
    check NaN.toYaml == ".nan"

  test "options and distinct":
    check none(int).toYaml == "null"
    check some(1).toYaml == "1"
    check 1.5.Meters.toYaml == "1.5"

  test "plain strings":
    check "hello world".toYaml == "hello world"
    check "a:b".toYaml == "a:b"
    check 'x'.toYaml == "x"

  test "quoted strings":
    for s in ["", "no", "Yes", "ON", "null", "~", "true", "1", "1.10", "22:22",
        "-1", ".5", "+1", ".inf", "-", "- a", "a: b", "a #b", "#x", " lead",
        "trail ", "end:", "[x]", "{x}", "&a", "*a", "!t", "|", ">", "'q'", "\"q\"",
        "%d", "@x", "`x`", "tab\there", "bell\a"]:
      check s.toYaml.startsWith('"')
      check s.toYaml.fromYaml(string) == s
    check "say \"hi\"\\".toYaml == "say \"hi\"\\"
    check "\"hi\" \\".toYaml == "\"\\\"hi\\\" \\\\\""

  test "literal block strings":
    check "a\nb\n".toYaml == "|\n  a\n  b"
    check "a\nb".toYaml == "|-\n  a\n  b"
    check "a\n\nb".toYaml == "|-\n  a\n\n  b"
    for s in ["a\nb\n", "a\nb", "a\n\n  b\n", "x\n\n"]:
      check s.toYaml.fromYaml(string) == s
    check " a\nb".toYaml.startsWith('"')
