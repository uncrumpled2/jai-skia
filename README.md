# Jai Skia Bindings

Automatically generated Jai bindings for the [Skia](https://skia.org/) 2D graphics library.

## Supported Platforms

- **Windows** (x64) - MSVC ABI, requires `skia.dll`
- **Linux** (x64) - Itanium ABI, requires `libskia.so`
- **macOS** (x64/arm64) - Itanium ABI, requires `libskia.dylib`

## Requirements

### All Platforms
- Jai compiler

### Windows
- Pre-built `skia.dll` and `skia.dll.lib` (or `skia.lib`)
- `skia_dll_symbols.txt` (exported symbols list)
- LLVM/Clang or Visual Studio Build Tools (for building the helper DLL)

### Linux
- Pre-built `libskia.so`
- `libskia_symbols.txt` (exported symbols list, generated via `nm -D libskia.so`)
- GCC or Clang (for building the helper shared library)

### macOS
- Pre-built `libskia.dylib`
- Xcode Command Line Tools

## Building Skia

### Windows

Run the included build script:
```batch
build_skia.bat
```

This will:
1. Sync Skia dependencies
2. Configure a release build with `is_component_build=true` (creates DLL)
3. Build Skia
4. Copy `skia.dll` and `skia.dll.lib` to the project root

**Note:** For best performance, install [LLVM/Clang](https://releases.llvm.org/download.html) before building.

### Linux

```bash
cd skia
python3 tools/git-sync-deps
bin/gn gen out/Release --args='is_component_build=true is_official_build=false'
ninja -C out/Release skia
cp out/Release/libskia.so ..
```

## Generating Bindings

The bindings generator automatically detects the platform and generates appropriate bindings:

```bash
jai generate.jai
```

This produces platform-specific binding files:
- **Windows:** `skia_windows.jai`
- **Linux:** `skia_linux.jai`
- **macOS:** `skia_macos.jai`

The unified `skia.jai` loader automatically includes the correct platform bindings at compile time.

### Generating Symbol Lists

#### Windows
```bash
python get_exports.py
```
This creates `skia_dll_symbols.txt` from `skia.dll`.

#### Linux
```bash
nm -D libskia.so | awk '{print $3}' | sort -u > libskia_symbols.txt
```

## Building Your Project

### Quick Start

```bash
jai build.jai
```

The build script automatically:
1. Compiles `skia_ref_helper.cpp` into a platform-specific shared library
2. Builds the example application

### Manual Build Setup

```jai
#import "Basic";
#import "Compiler";

#run {
    set_build_options_dc(.{do_output=false});

    w := compiler_create_workspace("MyApp");
    options := get_build_options(w);
    options.output_executable_name = "myapp";

    // Add current directory to import path
    import_path: [..] string;
    array_add(*import_path, ..options.import_path);
    array_add(*import_path, ".");
    options.import_path = import_path;

    #if OS == .WINDOWS {
        // Windows: link against import libraries
        linker_args: [..] string;
        array_add(*linker_args, ..options.additional_linker_arguments);
        array_add(*linker_args, "skia.dll.lib");
        array_add(*linker_args, "skia_ref_helper.lib");
        options.additional_linker_arguments = linker_args;
    } else {
        // Linux/macOS: add library search path
        linker_args: [..] string;
        array_add(*linker_args, ..options.additional_linker_arguments);
        array_add(*linker_args, "-L.");
        options.additional_linker_arguments = linker_args;
    }

    set_build_options(options, w);
    add_build_file("main.jai", w);
}
```

Import the bindings in your code:
```jai
#load "skia.jai";
// or if set up as a module:
#import "skia";
```

## Running Your Program

### Windows
Ensure `skia.dll` and `skia_ref_helper.dll` are in the same directory as your executable or in the system PATH.

```batch
example.exe
```

### Linux
```bash
LD_LIBRARY_PATH="/path/to/jai/modules:." ./example
```

### macOS
```bash
DYLD_LIBRARY_PATH="." ./example
```

## Project Structure

```
jai-skia/
├── skia.jai              # Platform loader (includes correct bindings)
├── skia_windows.jai      # Windows-specific bindings (MSVC mangling)
├── skia_linux.jai        # Linux-specific bindings (Itanium mangling)
├── skia_macos.jai        # macOS-specific bindings (Itanium mangling)
├── generate.jai          # Bindings generator
├── build.jai             # Example build script
├── example.jai           # Example application
├── skia_ref_helper.cpp   # Reference counting helper (cross-platform)
├── wrapper.h             # C++ headers for binding generation
├── build_skia.bat        # Windows Skia build script
├── get_exports.py        # Windows DLL symbol extractor
├── skia_dll_symbols.txt  # Windows exported symbols
├── libskia_symbols.txt   # Linux exported symbols
├── skia.dll              # Windows Skia library
├── skia.dll.lib          # Windows import library
├── skia.lib              # Windows import library (copy)
└── skia/                 # Skia source tree
```

## API Differences from C++

### 1. Struct Initialization

C++ constructors are exposed as `Constructor` methods:

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

C++ methods become struct member functions with explicit `this` pointer:

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

Skia uses `sk_sp<T>` for reference-counted objects. In these bindings, `sk_sp` is a simple struct:

```jai
sk_sp :: struct(T: Type) {
    fPtr: *T;
}
```

Access the raw pointer via `.fPtr`:

```jai
sp_surface := SkSurfaces.WrapPixels(info, pixels, row_bytes, null);
surface := sp_surface.fPtr;
canvas := SkSurface.getCanvas(surface);
```

**Important:** The Jai bindings do NOT automatically call `unref()` when `sk_sp` goes out of scope.

#### Reference Counting Helpers

```jai
sk_ref_cnt_ref :: (ptr: *void) -> void;      // Increment reference count
sk_ref_cnt_unref :: (ptr: *void) -> void;    // Decrement (destroys at 0)
sk_ref_cnt_get_count :: (ptr: *void) -> s32; // Get count (debugging)

// Convenience wrappers
sk_sp_ref :: (sp: *$T/sk_sp);
sk_sp_unref :: (sp: *$T/sk_sp);
sk_sp_reset :: (sp: *$T/sk_sp, new_ptr: *T.element_type);
```

#### sk_sp By-Value ABI Issue

**Warning:** Functions taking `sk_sp<T>` by value have broken FFI semantics due to ABI differences.

**Solution:** Use safe wrapper functions:

```jai
// Safe wrappers for SkFont
SkFont_make :: (typeface: *SkTypeface, size: SkScalar) -> SkFont;
SkFont_setTypeface_safe :: (font: *SkFont, typeface: *SkTypeface);
SkFont_destroy :: (font: *SkFont);
```

### 4. Operator Renaming

| C++ Operator | Jai Name |
|--------------|----------|
| `operator+`  | `operator_plus` |
| `operator-`  | `operator_minus` |
| `operator*`  | `operator_mul` |
| `operator/`  | `operator_div` |
| `operator==` | `operator_eq` |
| `operator!=` | `operator_neq` |
| `operator[]` | `operator_subscript` |

### 5. Enums

```jai
SkBlendMode.Src
SkColorType.RGBA_8888_SkColorType
```

### 6. Platform-Specific Destructor Names

Some destructor names differ between platforms:

```jai
// Cleanup file stream
#if OS == .WINDOWS {
    SkFILEWStream.virtual_Destructor(*stream);
} else {
    SkFILEWStream.Destructor_Base(*stream);
}
```

## Complete Example

```jai
#import "Basic";
#load "skia.jai";

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

    // Draw text (platform-specific font handling)
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, 24.0);

    textPaint: SkPaint;
    SkPaint.Constructor(*textPaint);
    SkPaint.setColor(*textPaint, 0xFF000000);

    text := "Hello from Skia!";
    SkCanvas.drawSimpleText(canvas, text.data, cast(u64)text.count,
                            SkTextEncoding.kUTF8, 100.0, 450.0, font, textPaint);

    SkPaint.Destructor(*textPaint);

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
    #if OS == .WINDOWS {
        SkFILEWStream.virtual_Destructor(*stream);
    } else {
        SkFILEWStream.Destructor_Base(*stream);
    }
    SkPaint.Destructor(*paint);
    free(pixels);
}
```

## Troubleshooting

### "Unable to resolve foreign symbol"
The symbol is not exported from the Skia library. Check if it's commented out in the platform bindings file.

### Windows: "skia.dll not found"
Ensure `skia.dll` is in the same directory as the executable or in your PATH.

### Windows: "skia.lib not found" during linking
Copy `skia.dll.lib` to `skia.lib`:
```batch
copy skia.dll.lib skia.lib
```

### Linux: "error while loading shared libraries: libskia.so"
```bash
LD_LIBRARY_PATH="." ./myapp
```

### Linux: "cannot open shared object file: libbacktrace.so.0"
```bash
LD_LIBRARY_PATH="/path/to/jai/modules:." ./myapp
```

### Crash on surface creation
Ensure `SkImageInfo` is properly initialized with valid color type and alpha type.

### Helper library not found
Run the build script to compile it:
```bash
jai build.jai
```

Or build manually:

**Windows (with LLVM):**
```batch
"C:\Program Files\LLVM\bin\clang-cl.exe" /LD /O2 skia_ref_helper.cpp /Fe:skia_ref_helper.dll
```

**Linux:**
```bash
g++ -shared -fPIC -O2 -o skia_ref_helper.so skia_ref_helper.cpp
```

**macOS:**
```bash
clang++ -shared -fPIC -O2 -o skia_ref_helper.dylib skia_ref_helper.cpp
```

### Font not rendering
Use the safe wrapper functions instead of passing `sk_sp<SkTypeface>` by value:
```jai
font := SkFont_make(typeface_ptr, 24.0);
```

## Unavailable Functions

Many inline functions, template instantiations, and internal methods are not exported from the Skia shared library and are commented out in the bindings. If you need such functionality:

1. Implement it in Jai using available primitives
2. Rebuild Skia with different export settings
3. Create a C++ wrapper library that exports the needed functions

## License

These bindings are provided as-is. Skia is licensed under the BSD 3-Clause License - see [Skia's license](https://skia.org/docs/dev/design/license/).
