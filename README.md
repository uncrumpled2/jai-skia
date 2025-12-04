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

The `build.jai` script automatically compiles `skia_ref_helper.cpp` into `skia_ref_helper.so` if it doesn't exist. This helper library is required for reference counting functionality.

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

The executable needs access to `libskia.so`, `skia_ref_helper.so`, and Jai's `libbacktrace.so.0`:

```bash
LD_LIBRARY_PATH="/path/to/jai/modules:." ./myapp
```

If all libraries are in the current directory and you have Jai installed at `/root/programming/jai`:
```bash
LD_LIBRARY_PATH="/root/programming/jai/modules:." ./myapp
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

**Important:** The Jai bindings do NOT automatically call `unref()` when `sk_sp` goes out of scope. For long-running applications, you should manually manage reference counts using the helper functions below.

#### sk_sp Reference Counting Helpers

Since `SkRefCntBase::ref()` and `unref()` are inlined in C++ headers and not exported from `libskia.so`, these bindings include a helper library (`skia_ref_helper.so`) that provides reference counting:

```jai
// Increment reference count
sk_ref_cnt_ref :: (ptr: *void) -> void;

// Decrement reference count (calls destructor when count reaches 0)
sk_ref_cnt_unref :: (ptr: *void) -> void;

// Get current reference count (for debugging)
sk_ref_cnt_get_count :: (ptr: *void) -> s32;

// Convenience wrappers for sk_sp types
sk_sp_ref :: (sp: *$T/sk_sp);    // Increment refcount of sp.fPtr
sk_sp_unref :: (sp: *$T/sk_sp);  // Decrement refcount and set fPtr to null
sk_sp_reset :: (sp: *$T/sk_sp, new_ptr: *T.element_type);  // Replace with new pointer
```

Example cleanup:
```jai
sp_surface := SkSurfaces.WrapPixels(info, pixels, row_bytes, null);
// ... use surface ...
sk_sp_unref(*sp_surface);  // Clean up when done
```

#### sk_sp By-Value ABI Issue

**Warning:** Functions that take `sk_sp<T>` **by value** (not by pointer) have broken FFI semantics. The value gets corrupted when passed from Jai to C++ due to ABI differences in how single-pointer structs are passed.

Affected functions include:
- `SkFont.Constructor(sk_sp<SkTypeface>, ...)`
- `SkFont.setTypeface(sk_sp<SkTypeface>)`
- `SkPaint.setShader(sk_sp<SkShader>)`
- `SkPaint.setColorFilter(sk_sp<SkColorFilter>)`
- Any function with `sk_sp<T>` parameter (not `*sk_sp<T>`)

**Solution:** Use the safe wrapper functions or manually set `fPtr` fields:

```jai
// Safe wrappers for SkFont (recommended)
SkFont_make :: (typeface: *SkTypeface, size: SkScalar) -> SkFont;
SkFont_make :: (typeface: *SkTypeface, size: SkScalar, scaleX: SkScalar, skewX: SkScalar) -> SkFont;
SkFont_setTypeface_safe :: (font: *SkFont, typeface: *SkTypeface);
SkFont_destroy :: (font: *SkFont);  // Clean up typeface reference
```

Example with custom typeface:
```jai
// Load a typeface from a font directory
sp_fontmgr := SkFontMgr_New_Custom_Directory("/usr/share/fonts/truetype/dejavu");
sp_typeface := SkFontMgr.makeFromFile(sp_fontmgr.fPtr, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 0);

if sp_typeface.fPtr {
    // Use the safe wrapper to create a font with the typeface
    font := SkFont_make(sp_typeface.fPtr, 24.0);

    // Draw text
    paint: SkPaint;
    SkPaint.Constructor(*paint);
    SkCanvas.drawSimpleText(canvas, "Hello!", 6, .kUTF8, 100, 100, font, paint);

    // Clean up
    SkFont_destroy(*font);
    SkPaint.Destructor(*paint);
}

sk_sp_unref(*sp_fontmgr);
```

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

### "cannot open shared object file: skia_ref_helper.so"
The helper library wasn't built. Run the build script which will compile it automatically:
```bash
jai build.jai
```
Or build it manually:
```bash
g++ -shared -fPIC -O2 -o skia_ref_helper.so skia_ref_helper.cpp
```

### Font not rendering with custom typeface
If you're using `SkFont.Constructor` with an `sk_sp<SkTypeface>` parameter and text isn't rendering correctly, use the safe wrapper instead:
```jai
// Don't use: SkFont.Constructor(*font, typeface_sp, 24.0);
// Use this instead:
font := SkFont_make(typeface_sp.fPtr, 24.0);
```

## License

These bindings are provided as-is. Skia is licensed under the BSD 3-Clause License - see [Skia's license](https://skia.org/docs/dev/design/license/).
