# Some development instructions

## Checking that filament renderer works

There's a very simple test file called `test_render_filament.cc` that can be used to just render headless
a given mjcf model. The way to use it it's like this:

```bash
./build/bin/test_render_filament --model-path model/humanoid/humanoid.xml
```

To test using `gdb` to check for segfaults and errors, launch it like this:

```bash
gdb --args ./build/bin/test_render_filament --model-path model/humanoid/humanoid.xml
```

## Checking that studio works



