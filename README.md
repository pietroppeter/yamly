# yamly

⚠️ *work in progress*

A type-safe and loose parser for a reasonable yaml dialect (i.e. not the full yaml specs, but what you usually find around).
Parses yaml code directly to Nim types as in [jsony](https://github.com/treeform/jsony).
Indeed the implementation is a port of jsony to yaml.

Somewhat inspired by (Python library) [strictyaml](https://github.com/crdoconnor/strictyaml) for the idea that you should better give up on full Yaml specs and
and target a reasonable dialect (but I plan to support flow style)..
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

## usage

```nim
import yamly, std / options

type
  Dependency = object
    name: string
    version: Option[string]
  Package = object
    name: string
    version: string
    tags: seq[string]
    dependencies: seq[Dependency]

let s = """
name: yamly
version: 0.1.0 # a string field gets a string
tags: [yaml, nim]
dependencies:
  - name: nim
    version: ">= 1.6.0"
  - name: jsony
"""
let p = s.fromYaml(Package)
assert p.dependencies[1].version.isNone
echo p.toYaml
```

Supported types: integers (decimal, `0x` hex, `0o` octal, `0b` binary), floats (also `.inf`, `-.inf`, `.nan`),
bool, enum, char, string, Option, distinct, ref, object (also object variants), tuple (named as mapping, unnamed as sequence),
array, seq, set, HashSet, OrderedSet, Table, OrderedTable (also their ref versions) and JsonNode.

Hooks (as in jsony):
- parsing: `newHook(v: var T)` (defaults), `renameHook(v: var T, key: var string)`, `postHook(v: var T)`, or a full `parseHook(y: var YamlParseContext, v: var T)`
- dumping: `skipHook(T: typedesc, key: static string): bool` to skip a field, or a full `dumpHook(y: var YamlDumpContext, v: T)`

## the dialect (yaml without hell)

Parsing is directed by the Nim type, so there is no implicit typing:
if a field is a string you get a string, also for `no`, `1.10` or `22:22` (see [the yaml document from hell](https://ruudvanasseldonk.com/2023/01/11/the-yaml-document-from-hell)).

- strings: plain (also on multiple lines), single quoted, double quoted (with escapes), literal (`|`) and folded (`>`) block scalars with chomping (`-`, `+`) and indentation indicators
- booleans: only `true` and `false` (also `True`, `TRUE`, `False`, `FALSE`). `yes`, `no`, `on`, `off` are errors
- null (for Option and ref): `null`, `Null`, `NULL`, `~` or an empty value
- mappings: block and flow style (`{a: 1}`), keys are plain or quoted strings; keys match fields up to style (`user_name` and `user-name` match `userName`), unknown keys are ignored, missing keys keep their default value
- sequences: block (also at the same indentation of the parent key) and flow style (`[1, 2]`)
- an object variant needs its discriminator before the fields of its branches
- JsonNode resolves plain scalars with the yaml 1.2 core schema (`no` is a string, `0x10` an int)
- an optional `---` at the start and `...` at the end of the document, multiple documents are not supported
- the dumper quotes every string another yaml parser (1.1 or 1.2) could read as something else (`"no"`, `"1.10"`, `"y"`) and dumps multi line strings as literal block scalars

## todo

- [x] refactor to use YamlParseContext and YamlDumpContext?
- [x] refactor split in parse and dump separate submodules
- [x] symbols
  - [x] numbers
    - [x] dump
    - [x] parse
    - [x] octal and hex
  - [x] bool
  - [x] enum
- [x] containers
  - [x] object
    - [x] dump
      - [x] dump key that needs to be quoted (e.g. starts with ", contains invalid characters, ...)
    - [x] parse
    - [x] flow-style
    - [x] object variants
  - [x] sequence
    - [x] dump
    - [x] parse
    - [x] flow-style
  - [x] tuple
  - [x] array
    - [x] dump
  - [x] sets
  - [x] tables
- [x] string (non quoted, quoted and multiline)
- [x] null
- [x] "json"
- [x] distinct
- [x] document separator (single document only)
- [ ] api for multiple documents?
- [ ] strict mode (error on unknown keys)
- [ ] dump with flow style (e.g. for short sequences)?

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
