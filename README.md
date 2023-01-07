# yamly

⚠️ *work in progress*

A type-safe parser for a reasonable yaml dialect (i.e. not the full yaml specs, but what you usually find around).
Implementation is basically an adaptation of [jsony](https://github.com/treeform/jsony) to yaml.
Somewhat inspired by [strictyaml](https://github.com/crdoconnor/strictyaml) for features of yaml not implemented.
For a complete yaml 1.2 parser, use [NimYAML](https://github.com/flyx/NimYAML). 
For another take of a restricted yaml parses, check out [nyml](https://github.com/openpeep/nyml).

Features of Yaml that are **not** implemented:
- directives (stuff with %)
- anchors (&) and refs (*) and `<<`
- tagging with ! or !!
- complex mapping keys (which use ?)
- yaml set type (e.g. a list that uses `?` instead of `-`, or other formats). Note that a list can be parsed as set if the type is specified to be a nim bit set or hash set.

I will likely implement flow-style for sequences (`[1, 2]`, useful also for the empty sequence) but I will likely not implement it for objects (`{a:1,b:2}`).

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
    - [ ] parse
    - [ ] flow-style? likely not
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
