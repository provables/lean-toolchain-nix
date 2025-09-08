# Lean Toolchain

This flake provides the `elan`/`lake` toolchain for Lean. Its goal is to enable a
normal workflow (`lake build`, etc.), and also to provide a way to package the
project as the output of `nix build`.

## Usage

### Development environment

For using the toolchain in a development environment run:

```bash
nix develop                # use default version
nix develop .#lean-4_21    # use version 4.21
```

Inside the environment, use `lake` and its related tools normally.

### Building for deployment or composition

Build the toolchain with

```bash
nix build                         # default version
nix build .#lean-toolchain-4_21   # version 4.21
```

## License

MIT
