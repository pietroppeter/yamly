# yamly

⚠️ *work in progress*

A type-safe and loose parser for a reasonable yaml dialect (i.e. not the full yaml specs, but what you usually find around).
Parses yaml code directly to Nim types as in [jsony](https://github.com/treeform/jsony).
Indeed the implementation is sort of a port of jsony to yaml.

Somewhat inspired by (Python library) [strictyaml](https://github.com/crdoconnor/strictyaml) for how to define a reasonable dialect (but I plan to support flow style)..
For a complete yaml 1.2 parser, use [NimYAML](https://github.com/flyx/NimYAML). 
For another take of a restricted yaml parser, check out [nyml](https://github.com/openpeep/nyml).
Ah, there is also [yanyl](https://github.com/tanelso2/yanyl).

Features of Yaml that are **not** in scope of implementation:
- directives (stuff with %)
- anchors (&) and refs (*) and `<<`
- tagging with ! or !!
- complex mapping keys (which use ?)
- yaml set type (e.g. a list that uses `?` instead of `-`, or other formats). Note that a list can be parsed as set if the type is specified to be a nim bit set or hash set.
- cannot use tab for whitespace anywhere (in yaml you cannot use tab for indentation but you can use it for generic whitespace)

## todo

- [x] refactor to use YamlParseContext and YamlDumpContext?
- [x] refactor split in parse and dump separate submodules
- [ ] symbols
  - [x] numbers
    - [x] dump
    - [x] parse
    - [ ] octal and hex
  - [ ] bool
  - [ ] enum
- [ ] containers
  - [ ] object
    - [x] dump
      - [ ] dump key that needs to be quoted (e.g. starts with ", contains invalid characters, ...)
    - [ ] parse
    - [ ] flow-style
  - [ ] sequence
    - [x] dump
    - [ ] parse
    - [ ] flow-style
  - [ ] tuple
  - [ ] array
    - [x] dump
  - [ ] sets
  - [ ] tables
- [ ] string (non quoted, quoted and multiline)
- [ ] null
- [ ] "json"
- [ ] distinct
- [ ] document separator? which api?

## dev notes

- (!=yaml) disallowing tab in spaces
- (!=jsony) parseHook requires an indentation field
- (!=jsony) not implementing fast dumping and parsing of numbers
- (!=jsony) using unittest (I like the check output in case of failing test)
- (!=jsony) refactor api using YamlParseContext/YamlDumpcontext instead of exposing s, idx, ind in signatures
- (!=jsony) refactor: parse and dump are two separate modules

interesting features not (yet) present in jsony:
- strict mode
- easy way to skip fields when dumping
- automatic camel to snake when dumping?
