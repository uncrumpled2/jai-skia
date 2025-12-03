# Jai Skia Bindings

Automatically generated Jai bindings for the [Skia](https://skia.org/) 2D graphics library.

## Requirements

- Jai compiler
- Pre-built `libskia.so` (shared library)
- `libskia_symbols.txt` (exported symbols list, generated via `nm -D libskia.so`)

## Building the Bindings

1. Ensure `libskia.so` is in the project directory
2. Generate the symbols list:
   ```bash
   nm -D libskia.so | awk '{print $3}' | sort -u > libskia_symbols.txt
   ```
3. Run the bindings generator:
   ```bash
   jai generate.jai
   ```

This produces `skia.jai` with all necessary post-processing applied.

## Building Your Project

See `build.jai` for an example build script. Key points:

```jai
#import "Basic";
#import "Compiler";

#run {
    set_build_options_dc(.{do_output=false});

    w := compiler_create_workspace("MyApp");

    options := get_build_options(w);
    options.output_executable_name = "myapp";

    // Add current directory to import path for skia
    import_path: [..] string;
    array_add(*import_path, ..options.import_path);
    array_add(*import_path, ".");
    options.import_path = import_path;

    // Add linker path for libskia.so
    linker_args: [..] string;
    array_add(*linker_args, ..options.additional_linker_arguments);
    array_add(*linker_args, "-L.");
    options.additional_linker_arguments = linker_args;

    set_build_options(options, w);
    add_build_file("main.jai", w);
}
```

Import the bindings in your code:
```jai
#import "skia";
```

## Running Your Program

The executable needs access to both `libskia.so` and Jai's `libbacktrace.so.0`:

```bash
LD_LIBRARY_PATH="/path/to/jai/modules:." ./myapp
```

## API Differences from C++

### 1. Struct Initialization

C++ constructors are exposed as `Constructor` methods. Default initialization in Jai zero-initializes the struct, which may not match C++ default constructor behavior.

**C++:**
```cpp
SkPaint paint;  // Calls default constructor
```

**Jai:**
```jai
paint: SkPaint;
SkPaint.Constructor(*paint);  // Explicitly call constructor
```

### 2. Method Calls

C++ methods become struct member functions. Use dot syntax with explicit `this` pointer:

**C++:**
```cpp
paint.setColor(0xFFFF0000);
canvas->drawRect(rect, paint);
```

**Jai:**
```jai
SkPaint.setColor(*paint, 0xFFFF0000);
SkCanvas.drawRect(canvas, rect, paint);
```

### 3. Smart Pointers (`sk_sp<T>`)

Skia uses `sk_sp<T>` for reference-counted objects. In these bindings, `sk_sp` is a simple struct wrapper:

```jai
sk_sp :: struct(T: Type) {
    fPtr: *T;
}
```

Functions returning `sk_sp<T>` return this struct. Access the raw pointer via `.fPtr`:

**C++:**
```cpp
sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
SkCanvas* canvas = surface->getCanvas();
```

**Jai:**
```jai
sp_surface := SkSurfaces.WrapPixels(info, pixels, row_bytes, null);
surface := sp_surface.fPtr;
canvas := SkSurface.getCanvas(surface);
```

**Important:** The Jai bindings do NOT automatically call `unref()` when `sk_sp` goes out of scope. For long-running applications, you may need to manually manage reference counts (if the `unref` symbol is available).

### 4. Operator Renaming

C++ operators are renamed since Jai doesn't allow operator symbols in identifiers:

| C++ Operator | Jai Name |
|--------------|----------|
| `operator+`  | `operator_plus` |
| `operator-`  | `operator_minus` |
| `operator*`  | `operator_mul` |
| `operator/`  | `operator_div` |
| `operator+=` | `operator_plus_equals` |
| `operator-=` | `operator_minus_equals` |
| `operator*=` | `operator_mul_equals` |
| `operator/=` | `operator_div_equals` |
| `operator==` | `operator_eq` |
| `operator!=` | `operator_neq` |
| `operator[]` | `operator_subscript` |
| `operator<`  | `operator_less` |

### 5. Enums

Jai enums are strongly typed. Use the enum type prefix:

**C++:**
```cpp
SkBlendMode::kSrc
SkColorType::kRGBA_8888_SkColorType
```

**Jai:**
```jai
SkBlendMode.Src
SkColorType.RGBA_8888_SkColorType
```

### 6. Color Types

`SkColor` is a `u32` (ARGB format). `SkColor4f` is a struct with `fR`, `fG`, `fB`, `fA` float members:

**C++:**
```cpp
canvas->clear(SK_ColorWHITE);
// or
SkColor4f white = {1.0f, 1.0f, 1.0f, 1.0f};
canvas->drawColor(white, SkBlendMode::kSrc);
```

**Jai:**
```jai
white: SkColor4f;
white.fR = 1.0;
white.fG = 1.0;
white.fB = 1.0;
white.fA = 1.0;
SkCanvas.drawColor(canvas, white, .Src);
```

### 7. SkImageInfo Creation

Instead of static factory methods like `SkImageInfo::MakeN32Premul()`, manually construct the struct:

**C++:**
```cpp
SkImageInfo info = SkImageInfo::MakeN32Premul(800, 600);
```

**Jai:**
```jai
dimensions: SkISize;
dimensions.fWidth = 800;
dimensions.fHeight = 600;

colorInfo: SkColorInfo;
colorInfo.fColorType = .RGBA_8888_SkColorType;
colorInfo.fAlphaType = .Premul_SkAlphaType;

info: SkImageInfo;
info.fDimensions = dimensions;
info.fColorInfo = colorInfo;
```

### 8. File I/O with SkFILEWStream

**C++:**
```cpp
SkFILEWStream stream("output.png");
if (stream.isValid()) { ... }
```

**Jai:**
```jai
stream: SkFILEWStream;
SkFILEWStream.Constructor(*stream, "output.png");

if stream.fFILE {  // Check file handle directly
    // ... use stream
}

SkFILEWStream.Destructor_Base(*stream);  // Clean up
```

### 9. Destructors

Call destructors explicitly when done with objects that have them:

```jai
SkPaint.Destructor(*paint);
SkFILEWStream.Destructor_Base(*stream);
```

## Unavailable Functions

Many inline functions, template instantiations, and internal methods are not exported from `libskia.so` and are commented out in the bindings. These include:

- Most operator overloads on basic types (SkPoint, SkRect, etc.)
- Many convenience constructors and factory methods
- Internal/private methods

If you need functionality from a commented-out function, you may need to:
1. Implement it in Jai using available primitives
2. Rebuild Skia with different export settings
3. Create a C++ wrapper library that exports the needed functions

## Complete Example

```jai
#import "Basic";
#import "skia";
#import "POSIX";

main :: () {
    // Setup image info
    dimensions: SkISize;
    dimensions.fWidth = 800;
    dimensions.fHeight = 600;

    colorInfo: SkColorInfo;
    colorInfo.fColorType = .RGBA_8888_SkColorType;
    colorInfo.fAlphaType = .Premul_SkAlphaType;

    info: SkImageInfo;
    info.fDimensions = dimensions;
    info.fColorInfo = colorInfo;

    // Allocate pixel buffer and create surface
    pixel_size := 800 * 600 * 4;
    pixels := alloc(pixel_size);
    memset(pixels, 0, pixel_size);

    sp_surface := SkSurfaces.WrapPixels(info, pixels, 800 * 4, null);
    surface := sp_surface.fPtr;

    if !surface {
        print("Failed to create surface\n");
        return;
    }

    canvas := SkSurface.getCanvas(surface);

    // Draw white background
    white: SkColor4f;
    white.fR = 1.0; white.fG = 1.0; white.fB = 1.0; white.fA = 1.0;
    SkCanvas.drawColor(canvas, white, .Src);

    // Draw red rectangle
    paint: SkPaint;
    SkPaint.Constructor(*paint);
    SkPaint.setColor(*paint, 0xFFFF0000);

    rect: SkRect;
    rect.fLeft = 100; rect.fTop = 100;
    rect.fRight = 300; rect.fBottom = 300;

    SkCanvas.drawRect(canvas, rect, paint);

    // Encode to PNG
    sp_image := SkSurface.makeImageSnapshot(surface);
    image := sp_image.fPtr;

    stream: SkFILEWStream;
    SkFILEWStream.Constructor(*stream, "output.png");

    if stream.fFILE {
        pixmap: SkPixmap;
        if SkImage.peekPixels(image, *pixmap) {
            options: SkPngEncoder.Options;
            if SkPngEncoder.Encode(*stream, pixmap, options) {
                print("Saved output.png\n");
            }
        }
    }

    // Cleanup
    SkFILEWStream.Destructor_Base(*stream);
    SkPaint.Destructor(*paint);
    free(pixels);
}
```

## Troubleshooting

### "Unable to resolve foreign symbol"
The symbol is not exported from `libskia.so`. Check if it's commented out in `skia.jai`. You may need to implement the functionality differently or rebuild Skia.

### "error while loading shared libraries: libskia.so"
Set `LD_LIBRARY_PATH` to include the directory containing `libskia.so`:
```bash
LD_LIBRARY_PATH="." ./myapp
```

### "cannot open shared object file: libbacktrace.so.0"
Add Jai's modules directory to `LD_LIBRARY_PATH`:
```bash
LD_LIBRARY_PATH="/path/to/jai/modules:." ./myapp
```

### Crash on surface creation
Ensure your `SkImageInfo` is properly initialized with valid color type and alpha type. Zero-initialized structs may have invalid enum values.

## License

These bindings are provided as-is. Skia is licensed under the BSD 3-Clause License - see [Skia's license](https://skia.org/docs/dev/design/license/).
