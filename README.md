# syamly

a type-safe parser for a reasonable yaml dialect.
Inspired by [strictyaml](https://github.com/crdoconnor/strictyaml)
and [jsony](https://github.com/treeform/jsony)

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
