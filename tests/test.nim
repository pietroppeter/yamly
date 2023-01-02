import syamly

block:
  doAssert toYaml(1) == "1"
  doAssert toYaml(3.14) == "3.14"
  doAssert toYaml(-1) == "-1"
  doAssert toYaml(-0.1) == "-0.1"
