# Language Implementation Overview

Building any programming language or interpreter involves several standard phases. First the **lexer/tokenizer** scans raw source text into a stream of tokens (identifiers, keywords, numbers, operators, etc.). Next a **parser** consumes tokens according to the language’s grammar and builds a **parse tree** or **Abstract Syntax Tree (AST)** representing the program’s structure.  For example, CPython’s compiler runs these steps in order: *Python code → parse tree → AST → symbol tables → (optionally) a control-flow graph → optimized bytecode*. Once we have an AST, the compiler generates a **code object** (in CPython, a `PyCodeObject`) containing optimized bytecode. Finally, the interpreter’s **VM loop** executes that bytecode on a stack-based virtual machine.  A concise summary of these phases is given by JunWei Song’s CPython-Internals notes:

* *Lexer*: split source into tokens (Python’s C code and `tokenize.py` handle this).
* *Parser*: apply the Python grammar to tokens to build a parse tree and then an AST.
* *Compiler*: transform the AST into optimized bytecode in a code object.
* *Interpreter*: execute bytecode using frames and an evaluation loop.

This pipeline means Python is **both** compiled (to bytecode) and interpreted (that bytecode is then run).

## Lexical Analysis (Tokenization)

In CPython, lexical analysis is performed by the `Parser/tokenizer.c` code (and the `Lib/tokenize.py` library). The lexer reads characters and groups them into tokens: names, numbers, string literals, operators, etc. For example, the line `a = 4` produces tokens like `Name:a`, `EQUAL:'='`, `NUMBER:4`.  This step handles comments (`#`), string escaping, indentation rules, and more.  In a Luau-based interpreter, you would hand-code a tokenizer or use Lua’s pattern matching to scan the input string character by character. Each token is typically represented by a type (e.g. `NAME`, `NUMBER`, `PLUS`, etc.) and value. Good structure (and tests) here are crucial, since errors in lexing will break parsing. As one teaching example notes, the first step is to write a simple lexer to produce a token list, then proceed to parsing.

## Parsing and the AST

Parsing applies Python’s grammar to the token stream. Python’s grammar (in `Grammar/python.gram`) describes valid sequences of statements and expressions.  Since Python 3.9, CPython uses a **PEG parser** (PEP 617) which can naturally handle Python’s syntax. The parser organizes tokens into a parse tree and then transforms that into an **Abstract Syntax Tree (AST)**. The AST is a higher-level representation where each node represents a syntactic element (if-statement, loop, function call, etc.).  For example, parsing `x = 2+2` produces an AST with an `Assign` node whose children include a `Name('x')`, a `BinOp(Num(2), Add, Num(2))`, etc.  Python’s standard `ast` module can generate and inspect these trees: `ast.parse("x=2+2")` yields an AST which can be compiled into a code object.

In your interpreter, you would write a parser (often recursive-descent in a language like Luau) that recognizes Python 3.12 syntax and builds a tree of AST nodes (you can use Lua tables or objects to represent nodes). As shown in CPython-internals documentation, one can imagine tokens feeding the parser one-by-one, building up nested lists or nodes until a complete parse is done.  The AST abstracts away punctuation and grouping so you can later generate code or interpret behavior.  Notably, Python’s AST node types and “abstract grammar” are documented in the `ast` library docs (and evolve between versions).

### Python 3.12 Syntax Updates

To support Python 3.12 in your Luau interpreter, you must handle its new grammar features.  Python 3.12 introduced new syntax for **generics** (PEP 695) and formalized **f-strings** (PEP 701), among other things.  Specifically:

* **Type Parameters (PEP 695)**: Python 3.12 allows a compact syntax for generics. For example, you can write `class list[T]: ...` or `def max[T](args: Iterable[T]) -> T: ...`, and use a new `type` statement for aliases (e.g. `type Point = tuple[float, float]`).
* **F-Strings (PEP 701)**: The grammar for f-strings was relaxed so any valid expression (including multiline expressions, quotes, escapes) can appear inside `{...}` in an f-string.

Your parser will need to recognize these constructs.  (If you need more detail, the official *“What’s New in Python 3.12”* notes enumerate these changes.)  Essentially, add the new syntax rules to your parsing logic so that your AST can include the new node types (e.g. a `Subscript` node for `list[T]`, `TypeAlias` node for `type x = ...`, and `FormattedValue` for f-strings).  Until Python 3.10, pattern-matching (PEP 634) also introduced new AST forms; make sure to include those too if targeting full 3.12 support.

## Compilation to Bytecode

After parsing, CPython **compiles** the AST into bytecode.  This happens in `Python/compile.c`: it walks the AST and emits instructions (like `LOAD_FAST`, `BINARY_ADD`, etc.) into a `code` object.  JunWei Song’s CPython-internals notes summarize the steps: after AST, CPython generates a symbol table, builds (optionally) a control-flow graph, applies simple optimizations (peephole optimizations like constant-folding), and finally emits bytecode.  The result is a `PyCodeObject` that contains the bytecode array (`co_code`), constants, variable names, and other metadata.

For example, compiling:

```python
def foo(x,y): 
    return x+y
```

produces a code object whose `co_code` might be the bytes for `LOAD_FAST 0; LOAD_FAST 1; BINARY_ADD; RETURN_VALUE`. You can inspect it at runtime: Python allows accessing `foo.__code__.co_code`, and the `dis` module can disassemble it into human-readable form.  Notably, code objects *are themselves Python objects* (they have a `PyObject_HEAD` and can be introspected).

In a Luau interpreter, you have two main options: interpret the AST directly (tree-walking) or generate your own bytecode and implement a simple VM.  The PyLua author started by directly executing the AST for simplicity.  Generating custom bytecode can improve performance; in fact, PyLua’s developer considered reading CPython’s `.pyc` format but found it too tied to C internals, so he’s designing a *simpler* bytecode for Roblox.  If you go this route, define a set of opcodes (LOAD, ADD, CALL, etc.) and an array format, then implement an evaluation loop in Luau that mimics Python’s semantics.

## CPython Execution Model and Object System

CPython executes bytecode on a stack-based virtual machine. When a function or module runs, CPython creates a **frame object** (`PyFrameObject`) that holds the code object, execution stack, local/global namespaces, and a link to the caller frame.  The core interpreter (in `ceval.c`) then repeatedly fetches and executes bytecode instructions using that frame.  For example, on `LOAD_FAST 0`, it pushes a local variable onto the stack; on `BINARY_ADD` it pops two values, adds them, and pushes the result.  The interpreter loop (an often-cited big `switch` statement) continues until it hits `RETURN_VALUE`, unwinding the frame.

Under the hood, Python objects are C structs with a common header.  Every `PyObject` begins with a `PyObject_HEAD` containing a reference count and a pointer to a `PyTypeObject` (which describes the object’s type and methods). For instance, a `PyCodeObject` and `PyFrameObject` are both full Python objects with headers.  To create a new type in CPython, you define a C struct (starting with `PyObject_HEAD`) and set its `ob_type` field to a `PyTypeObject` structure. In essence, *all* values (lists, dicts, functions, code objects, even integers and strings) are heap-allocated `PyObject*`.  CPython uses **reference counting** (plus a cyclic GC) to manage memory.

One critical feature of CPython is the **Global Interpreter Lock (GIL)**: a mutex that ensures only one native thread executes Python bytecode at a time. This simplifies object memory management.  (Python 3.12 changes this to a “per-interpreter” GIL via PEP 684, effectively splitting the lock so that sub-interpreters can run truly in parallel.) This detail matters if you plan threading; in Luau, you would manage concurrency according to Roblox’s model (which likely means no real parallel threads for your interpreter).

## Building a Python Interpreter in Luau

To implement Python in Luau (as in the PyLua project), you essentially re-create the above pipeline in Luau code. Key components include:

* **Tokenizer Module:** Read input strings, produce tokens. Handle numbers, strings, names, indentation, comments, etc. (Lua’s `string` library and patterns can help, but you may need manual loops for Python’s rules.) This module corresponds to Python’s C tokenizer.
* **Parser Module:** Consume tokens to build an AST. You can hand-write a recursive-descent parser reflecting the Python grammar. Start by implementing basic expressions, then statements (if/for/while/etc.), following examples of grammar or the changes from 3.12. The parser should create node objects (tables) like `Assign`, `If`, `For`, etc. (Similar to how a teaching example builds ASTs for a toy language.)
* **AST Evaluator/Interpreter:** Walk the AST nodes and execute them. Maintain an environment (nested scopes of variables). For example, evaluating an assignment node means evaluating the right-hand expression and storing it in the current scope’s table. Control-flow nodes translate to Luau control flow. You’ll re-implement Python semantics (e.g. truthiness rules, exception handling, etc.) in this evaluator. PyLua’s code splits out evaluator logic for expressions and statements (plus modules for built-ins).
* **(Optional) Bytecode Compiler/VM:** If you want better performance, compile the AST to your own bytecode format and write a loop to execute it. This is more work but as PyLua’s creator noted, avoids re-parsing each time and can reuse compiled scripts. PyLua plans a “simplified bytecode format” suited for Roblox.
* **Built-in Environment:** Implement Python’s built-in types (`list`, `dict`, `str`, etc.), functions (`len`, `print`, etc.), and operators. You can back them with Luau tables/functions. The PyLua project already supports many basics (lists, loops, `range()`, etc.) and aims to add `def` (functions), dictionaries, classes, etc. Tracking the CPython object model helps: for instance, each PyLua value could be a table tagged with a type so you can mimic method lookups like `s.upper()` calling the right routine.

As a real example, PyLua’s architecture explicitly includes a *Tokenizer*, *Parser (syntax trees)*, and *Evaluator (expressions)*, with separate modules for control flow and built-ins. They note it **“actually parses and executes Python code in real time”** inside Roblox, rather than pre-translating to Luau. (Because Roblox disallows dynamic file loading, reading `.pyc` files isn’t possible, so the interpreter must start from source strings or preloaded scripts.)

## Summary

In summary, making a Python interpreter means replicating CPython’s stages in your target environment.  Study CPython’s source if possible, or guides to its internals.  You’ll build a lexer, a parser/AST, and an executor.  In Luau, you’ll write each piece in Lua code.  Key CPython lessons to apply include: the two-phase compile/interpret model (source→bytecode→VM), the structure of AST and code objects, and Python’s grammar details (especially changes in 3.12).  With careful design of AST data structures and execution semantics, you can emulate Python’s behavior.  Leveraging existing knowledge (like the PyLua project’s modular structure) will greatly help.  In the end, your Luau interpreter will mimic CPython’s pipeline – tokenize → parse → execute – but with all data and logic implemented in Luau rather than C.

**Sources:** CPython’s developer documentation and source (including *InternalDocs* and the `ast` reference) describe the compile-and-execute process.  Explanatory guides (e.g. Sourcerer blog on CPython internals) and the PyLua project forum posts illustrate practical interpreter architectures.  These emphasize the lexer→parser→AST→bytecode→VM sequence.  The “What’s New” docs for Python 3.12 highlight new grammar/features to support.
