# Abstract Machine

**A lightweight, Erlang-inspired virtual machine for concurrent, fault-tolerant applications in Crystal.**

[![Crystal](https://img.shields.io/badge/crystal-1.15+-blue?logo=crystal)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/konjac-lang/abstract_machine?style=social)](https://github.com/konjac-lang/abstract_machine)
[![Build Status](https://github.com/konjac-lang/abstract_machine/actions/workflows/ci.yml/badge.svg)](https://github.com/konjac-lang/abstract_machine/actions)

This project combines a clean **stack-based bytecode interpreter** with **actor-model concurrency**, lightweight processes, message passing, supervision trees, and built-in fault tolerance — all implemented in pure Crystal.

Inspired by Erlang's BEAM, but designed to be simple, hackable, and embeddable.

## Features

- **Stack-based VM** — Predictable execution with a growing instruction set
- **Actor-model concurrency** — Thousands of lightweight processes, isolated mailboxes
- **Fault tolerance** — Linking, monitoring, supervision trees (one-for-one, one-for-all)
- **First-class data** — Maps, arrays, strings, atoms with native operations
- **Built-in primitives** — IO, process operations, yield/scheduling hooks
- **Pure Crystal** — No external dependencies beyond stdlib (easy to embed/extend)

## Quick Start

### Installation

Add AbstractMachine to your `shard.yml`:

```yaml
dependencies:
  abstract_machine:
    github: konjac-lang/abstract_machine
```

Then run:

```bash
shards install
```

## Why choose this project?

- Want to experiment with actor-model semantics without Erlang/OTP?
- Building a domain-specific language or embedded runtime in Crystal?
- Curious how BEAM-like supervision can work in a stack VM?

This project is small (~few thousand LOC), readable, and meant for learning/hacking.

## Contributing

Contributions are super welcome — bug fixes, new instructions, examples, docs!

1. Fork it
2. Create branch (`git checkout -b feature/amazing-thing`)
3. Commit (`git commit -am 'Add amazing thing'`)
4. Push (`git push origin feature/amazing-thing`)
5. Open Pull Request

## Contributing

1. Fork it (<https://github.com/konjac-lang/abstract_machine/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Giorgi Kavrelishvili](https://github.com/grkek) - creator and maintainer
