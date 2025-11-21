# FPS

A simple FPS in [Zig](https://ziglang.org), 
based on <https://github.com/lizard-demon/fps>

> [!Note]
> Requires Zig 0.15.2+

## Build

Build a small native binary;

```console
$ zig build --release=small
```

> [!Tip]
> The `--release` flag for `zig build` takes the following values:
>
> - `fast`
> - `safe`
> - `small`

### Run

Build and run a small native binary;

```console
zig build run --release=small
```

Build and run a small [WebAssembly](https://webassembly.org/) binary in your browser;

```console
zig build run --release=small -Dtarget=wasm32-emscripten
```

### Test

You can run all the test cases like this;

```console
zig build test
```

## Input

Key           | Action
--------------|------------------
**W,A,S,D**   | Move
**Mouse**     | Look around  
**Space**     | Jump (with audio)
**Click**     | Capture mouse
**Escape**    | Release mouse
**Q**         | Quit
**P**         | Print player state
