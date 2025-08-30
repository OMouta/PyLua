# Contributing to PyLua

Thank you for your interest in contributing to PyLua! This document provides guidelines and information for contributors to the PyLua v0.3 rewrite project.

## 🎯 Project Overview

PyLua v0.3 is a complete rewrite of the Python interpreter for Luau/Roblox. We're building a production-quality Python 3.12-compliant interpreter following CPython's design principles with a Lupa-inspired API.

**Important**: We are currently in a major rewrite phase. Please read the [internalDocs/REWRITE_PLAN.md](./internalDocs/REWRITE_PLAN.md) to understand the current development phase and architecture goals.

## 🚀 Getting Started

### Prerequisites

- **Luau/Roblox Development Environment**: Familiarity with Luau syntax and Roblox development
- **Python Knowledge**: Understanding of Python 3.12 syntax and semantics
- **Git**: Basic Git workflow knowledge
- **Rokit**: Tool manager for Roblox projects (for managing Jelly and other tools)

### Development Setup

1. **Fork and Clone**

   ```bash
   git clone https://github.com/your-username/PyLua.git
   cd PyLua
   ```

2. **Install Development Tools**
   PyLua uses [Jelly](https://github.com/OMouta/Jelly) for project management and build scripts. Install it using [Rokit](https://github.com/rojo-rbx/rokit):

   ```bash
   # Install Rokit (if not already installed)
   # Follow instructions at: https://github.com/rojo-rbx/rokit

   # Install project tools (Jelly, Rojo, etc.)
   rokit install
   ```

   Alternatively, you can install Jelly directly from its [GitHub page](https://github.com/OMouta/Jelly).

3. **Understand the Architecture**
   - Read [internalDocs/README.md](./internalDocs/README.md) for documentation overview
   - Review [internalDocs/REWRITE_PLAN.md](./internalDocs/REWRITE_PLAN.md) for current phase
   - Study [internalDocs/LANGUAGE_IMPLEMENTATION.md](./internalDocs/LANGUAGE_IMPLEMENTATION.md) for technical background

4. **Set Up Development Environment**
   - Install Roblox Studio or your preferred Luau development environment
   - Configure your editor with Luau syntax highlighting
   - Familiarize yourself with the test framework in `tests/`

## 📋 Current Development Phase

**Phase 1: Foundation** *(Current Focus)*

- ✅ Project structure and module system
- ✅ Comprehensive lexer with Python 3.12 tokenization
- ✅ AST system foundation
- 🔄 Core parser implementation
- ⏳ Object system foundation

See [internalDocs/REWRITE_PLAN.md](./internalDocs/REWRITE_PLAN.md) for detailed phase information.

## 🤝 How to Contribute

### 1. Choose Your Contribution Type

#### 🐛 Bug Reports

- Check existing issues first
- Use the bug report template
- Include minimal reproduction steps
- Specify which version/branch you're using

#### 💡 Feature Requests

- Review the rewrite plan to ensure alignment with project goals
- Use the feature request template
- Consider Python 3.12 compliance requirements
- Discuss major features in issues before implementation

#### 📝 Documentation

- Improve existing documentation
- Add code examples
- Fix typos and clarifications
- Update documentation when implementing features

#### 🔧 Code Contributions

- Follow the current development phase priorities
- Implement features according to the architecture plan
- Write comprehensive tests for new functionality
- Follow Python 3.12 compliance guidelines

### 2. Code Contribution Workflow

1. **Create an Issue** (for non-trivial changes)
   - Describe the problem or enhancement
   - Discuss approach with maintainers
   - Get feedback before starting work

2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

3. **Implement Your Changes**
   - Follow the coding standards (see below)
   - Write tests for new functionality
   - Update documentation as needed

4. **Test Your Changes**

   PyLua uses Jelly for project management and build scripts. Available commands:

   ```bash
   # Build the project
   jelly run build

   # Run tests (when test framework is implemented)
   jelly run test

   # Run development checks
   jelly run check
   ```

   You can also run scripts directly using Jelly's configuration in `jelly.json`.

5. **Submit a Pull Request**
   - Use the PR template
   - Link to related issues
   - Provide clear description of changes
   - Include test results

## Coding Standards

### Luau Style Guidelines

```luau
-- Module header with clear purpose
local ModuleName = {}

-- Import dependencies at the top
local Types = require('src.PyLua.types')
local Utils = require('src.PyLua.utils')

-- Export types for other modules
export type ModuleType = {
    field: string,
    method: (self: ModuleType, param: number) -> boolean
}

-- Private functions with local scope
local function privateHelper(param: string): number
    -- Implementation with proper error handling
    if not param then
        error("Parameter required")
    end
    return #param
end

-- Public API functions with type annotations
function ModuleName.publicFunction(input: string): (boolean, string?)
    local result = privateHelper(input)
    if result > 0 then
        return true, nil
    else
        return false, "Invalid input"
    end
end

-- Return module table
return ModuleName
```

### Python 3.12 Compliance

- **Follow Python semantics exactly** where possible
- **Reference CPython behavior** for implementation details
- **Use Python-like naming** for opcodes and internal structures
- **Implement proper operator precedence** according to Python rules
- **Handle edge cases** as Python 3.12 would

### Error Handling

```luau
-- Always include source location information
local function parseExpression(tokens: {Token}, pos: number): (Expr?, string?)
    if not tokens[pos] then
        return nil, string.format("Unexpected end of input at position %d", pos)
    end
    
    -- parsing logic with error context
    local expr, err = parseSubexpression(tokens, pos)
    if err then
        return nil, string.format("Expression parsing failed at line %d: %s", 
                                tokens[pos].line, err)
    end
    
    return expr, nil
end
```

### Testing Requirements

- **Unit tests** for all new functions and modules
- **Integration tests** for complex interactions
- **Error case testing** with proper error message validation
- **Python compliance tests** comparing with CPython behavior

Example test structure:

```luau
-- tests/unit/test_lexer.luau
local function testBasicTokenization()
    local lexer = require('src.PyLua.lexer')
    local tokens = lexer.tokenize("x = 42")
    
    assert(#tokens == 3, "Expected 3 tokens")
    assert(tokens[1].type == "NAME", "Expected NAME token")
    assert(tokens[1].value == "x", "Expected 'x' value")
    assert(tokens[2].type == "ASSIGN", "Expected ASSIGN token")
    assert(tokens[3].type == "NUMBER", "Expected NUMBER token")
    assert(tokens[3].value == 42, "Expected 42 value")
end
```

## 🔍 Code Review Process

### For Contributors

- **Self-review** your code before submitting
- **Test thoroughly** including edge cases
- **Update documentation** for API changes
- **Be responsive** to review feedback

### Review Criteria

- **Correctness**: Does the code work as intended?
- **Python Compliance**: Does it match Python 3.12 behavior?
- **Architecture Alignment**: Does it fit the overall design?
- **Test Coverage**: Are there sufficient tests?
- **Documentation**: Is it properly documented?
- **Performance**: Is it reasonably efficient?

## 🚨 Important Guidelines

### What to Focus On

- **Current phase priorities** from the rewrite plan
- **Python 3.12 compliance** and below
- **Clean, maintainable code** with proper separation of concerns
- **Comprehensive testing** for reliability
- **Clear documentation** for future contributors

### What to Avoid

- **Don't copy from old implementation** - it's fundamentally flawed
- **Don't skip the architecture plan** - follow the established phases
- **Don't ignore Python semantics** - maintain compliance
- **Don't submit untested code** - tests are mandatory
- **Don't make breaking changes** without discussion

## 🏷️ Issue Labels

- `phase-1-foundation` - Core infrastructure work
- `phase-2-parser` - Parser implementation
- `phase-3-objects` - Object system development
- `bug` - Bug reports and fixes
- `enhancement` - New features
- `documentation` - Documentation improvements
- `good-first-issue` - Beginner-friendly tasks
- `help-wanted` - Community assistance needed
- `python-compliance` - Python behavior accuracy issues

## 💬 Communication

### Where to Ask Questions

- **GitHub Issues** for bug reports and feature requests
- **GitHub Discussions** for general questions and design discussions
- **Pull Request comments** for code-specific questions

### Getting Help

- Review the documentation in `internalDocs/`
- Check existing issues and discussions
- Ask specific, well-researched questions
- Provide context and examples when asking for help

## 🎉 Recognition

Contributors will be recognized in:

- GitHub contributor list
- Release notes for significant contributions
- Project documentation for major features

## 📜 Code of Conduct

Be respectful, constructive, and inclusive. We're building something great together!

- **Be patient** with new contributors
- **Provide constructive feedback** in reviews
- **Ask questions** when something is unclear
- **Help others** when you can

## 🔗 Useful Resources

### Python & Language Implementation

- [Python 3.12 Language Reference](https://docs.python.org/3.12/reference/)
- [CPython Developer Documentation](https://devguide.python.org/)

### Luau & Roblox Development

- [Luau Documentation](https://luau-lang.org/)
- [Roblox Creator Documentation](https://create.roblox.com/docs)

### Development Tools

- [Jelly](https://github.com/OMouta/Jelly) - Project management and build tool
- [Rokit](https://github.com/rojo-rbx/rokit) - Toolchain manager for Roblox projects
- [Rojo](https://rojo.space/) - Project management tool for Roblox

---

Thank you for contributing to PyLua! Your efforts help make Python accessible within the Roblox ecosystem. 🐍✨
