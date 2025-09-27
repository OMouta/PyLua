# PyLua Internal Documentation

This directory contains internal documentation for PyLua v0.3 development. These documents are intended for contributors, maintainers, and anyone interested in understanding the implementation details of the PyLua interpreter.

## Documents Overview

### [REWRITE_PLAN.md](./REWRITE_PLAN.md)

#### Complete development roadmap and architecture specification

This is the master planning document for PyLua v0.3. It outlines:

- Current issues with v0.2 and motivation for the rewrite
- Target architecture following CPython's design principles
- Detailed implementation phases (Foundation → Parser → Object System → VM → Built-ins)
- Python 3.12 compliance goals and version limitations
- API design inspired by Lupa (inverse Python-in-Luau)
- Testing strategy and success criteria
- Future roadmap for v3.1+ features

**Start here** if you want to understand the overall project direction and implementation plan.

### [LANGUAGE_IMPLEMENTATION.md](./LANGUAGE_IMPLEMENTATION.md)

#### Guide on interpreter implementation

This document provides background on how programming language interpreters work, with specific focus on:

- The standard interpreter pipeline: Lexer → Parser → AST → Compiler → VM
- CPython's internal architecture and execution model
- Python 3.12 syntax features and grammar changes
- Object system design and memory management
- Bytecode compilation and virtual machine execution
- Practical guidance for implementing Python semantics in Luau

**Essential reading** for understanding the theoretical foundation and technical challenges of building a Python interpreter.

## Target Audience

### For Contributors

- **New contributors**: Start with `REWRITE_PLAN.md` to understand the project scope and current phase
- **Core developers**: Use both documents as reference for implementation decisions
- **Language experts**: `LANGUAGE_IMPLEMENTATION.md` provides the theoretical foundation

### For Maintainers

- Architecture decisions should align with the principles outlined in these documents
- Use the phase breakdown in `REWRITE_PLAN.md` for milestone planning
- Reference the compliance goals when evaluating feature requests

## Key Design Principles

Based on these documents, PyLua v0.3 follows these core principles:

1. **Python 3.12 Compliance**: Support Python 3.12 syntax and below for focused, manageable scope
2. **CPython-Inspired Architecture**: Follow proven interpreter design patterns
3. **Lupa-Style API**: Familiar interface for embedders (Python-in-Luau)
4. **Modular Design**: Clean separation between lexer, parser, compiler, and VM
5. **Roblox Optimization**: Designed specifically for the Roblox/Luau environment

## Contributing Guidelines

When contributing to PyLua v0.3:

1. **Read both documents** to understand the architecture and goals
2. **Follow the phase plan** - implement features in the correct order
3. **Maintain Python compliance** - reference CPython behavior for accuracy
4. **Write comprehensive tests** - each component needs thorough test coverage
5. **Document design decisions** - update these docs when making architectural changes

## Quick Reference

| Need to... | Reference |
|------------|-----------|
| Understand project scope and goals | `REWRITE_PLAN.md` - Overview & Design Principles |
| Implement lexer/tokenizer | `LANGUAGE_IMPLEMENTATION.md` - Lexical Analysis |
| Design AST nodes | `LANGUAGE_IMPLEMENTATION.md` - Parsing and AST |
| Build the virtual machine | `LANGUAGE_IMPLEMENTATION.md` - CPython Execution Model |
| Check implementation phases | `REWRITE_PLAN.md` - Implementation Phases |
| Understand Python 3.12 features | `LANGUAGE_IMPLEMENTATION.md` - Python 3.12 Syntax Updates |

## External References

These documents reference and build upon:

- [Python 3.12 Language Reference](https://docs.python.org/3.12/reference/)
- [CPython Developer Documentation](https://devguide.python.org/)
- [CPython Internals Guide](https://github.com/python/cpython/tree/main/InternalDocs)
- [Lupa Documentation](https://github.com/scoder/lupa) (for API inspiration)
