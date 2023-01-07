# yamly

A type-safe parser for a reasonable yaml dialect (i.e. not the full yaml specs).
Implementation is basically an adaptation of [jsony](https://github.com/treeform/jsony) to yaml.
Somewhat inspired by [strictyaml](https://github.com/crdoconnor/strictyaml).

## todo

- [ ] symbols
  - [x] numbers
    - [x] dump
    - [x] parse
  - [ ] boolean
  - [ ] enum
- [ ] containers
  - [ ] object
    - [x] dump
    - [ ] parse
  - [ ] sequence
    - [x] dump
  - [ ] tuple
  - [ ] array
  - [ ] sets
  - [ ] tables
- [ ] string
- [ ] json
- [ ] distinct

## dev notes

- (!=yaml) disallowing tab in spaces
- (!=jsony) parseHook requires an indentation field
- (!=jsony) not implementing fast dumping and parsing of numbers
- (!=jsony) using unittest (I like the check output in case of failing test)

interesting features not (yet) present in jsony:
- strict mode
- easy way to skip fields when dumping
- automatic camel to snake when dumping?
- YamlParseContext/YamlDumpcontext instead of exposing s, idx, ind in signatures?