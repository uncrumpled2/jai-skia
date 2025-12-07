#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
String :: #import "String";
#import "File";
#import "Hash_Table";

// Platform detection
IS_WINDOWS :: OS == .WINDOWS;
IS_LINUX   :: OS == .LINUX;
IS_MACOS   :: OS == .MACOS;

#run {
    set_build_options_dc(.{do_output=false});

    options: Generate_Bindings_Options;
    array_add(*options.source_files, "wrapper.h");

    // Include path for Skia
    array_add(*options.include_paths, "skia");

    // Platform-specific configuration
    output_filename: string;
    symbols_filename: string;
    sk_build_define: string;

    #if IS_WINDOWS {
        print("Generating bindings for Windows...\n");
        output_filename = "skia_windows.jai";
        symbols_filename = "skia_dll_symbols.txt";
        sk_build_define = "-DSK_BUILD_FOR_WIN";

        // MSVC include paths
        // These paths may need to be adjusted based on your VS installation
        array_add(*options.system_include_paths, "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Tools/MSVC/14.44.35207/include");
        array_add(*options.system_include_paths, "C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/ucrt");
        array_add(*options.system_include_paths, "C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/shared");
        array_add(*options.system_include_paths, "C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/um");

        // Use clang in MSVC-compatible mode
        array_add(*options.extra_clang_arguments, "-x", "c++", "-std=c++17");
        array_add(*options.extra_clang_arguments, "-fms-compatibility");
        array_add(*options.extra_clang_arguments, "-fms-extensions");
        array_add(*options.extra_clang_arguments, "-fdelayed-template-parsing");
        array_add(*options.extra_clang_arguments, sk_build_define);

    } else #if IS_LINUX {
        print("Generating bindings for Linux...\n");
        output_filename = "skia_linux.jai";
        symbols_filename = "libskia_symbols.txt";
        sk_build_define = "-DSK_BUILD_FOR_UNIX";

        // GCC/Linux system include paths
        array_add(*options.system_include_paths, "/usr/include/c++/13");
        array_add(*options.system_include_paths, "/usr/include/x86_64-linux-gnu/c++/13");
        array_add(*options.system_include_paths, "/usr/include/c++/13/backward");
        array_add(*options.system_include_paths, "/usr/lib/gcc/x86_64-linux-gnu/13/include");
        array_add(*options.system_include_paths, "/usr/local/include");
        array_add(*options.system_include_paths, "/usr/include/x86_64-linux-gnu");
        array_add(*options.system_include_paths, "/usr/include");

        array_add(*options.extra_clang_arguments, "-x", "c++", "-std=c++17");
        array_add(*options.extra_clang_arguments, sk_build_define);

    } else #if IS_MACOS {
        print("Generating bindings for macOS...\n");
        output_filename = "skia_macos.jai";
        symbols_filename = "libskia_symbols.txt";  // Will need macOS-specific symbols file
        sk_build_define = "-DSK_BUILD_FOR_MAC";

        // macOS system include paths (typical Xcode locations)
        array_add(*options.system_include_paths, "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1");
        array_add(*options.system_include_paths, "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include");

        array_add(*options.extra_clang_arguments, "-x", "c++", "-std=c++17");
        array_add(*options.extra_clang_arguments, sk_build_define);

    } else {
        print("Unsupported platform!\n");
        return;
    }

    // Common options
    options.strip_flags = 0;
    options.generate_compile_time_struct_checks = false;

    print("Output file: %\n", output_filename);
    print("Symbols file: %\n", symbols_filename);

    // Generate to a temp file first
    temp_filename := "skia_temp.jai";
    success := generate_bindings(options, temp_filename);

    if success {
        print("Post-processing %...\n", output_filename);
        file_content, read_success := read_entire_file(temp_filename);
        if !read_success {
            print("Error reading generated file.\n");
            return;
        }

        // 1. Replace unknown library with libskia
        file_content = String.replace(file_content, "#foreign __UnknownLib", "#foreign libskia");

        // 2. Prepend platform-specific header
        header := get_platform_header();
        file_content = tprint("%\n%", header, file_content);

        // 3. Rename operators (both declarations and calls)
        file_content = apply_operator_renames(file_content);

        // 4. Apply struct fixes
        file_content = apply_struct_fixes(file_content);

        // 5. Apply enum fixes
        file_content = apply_enum_fixes(file_content);

        // 6. Apply syntax fixes
        file_content = apply_syntax_fixes(file_content);

        // 7. Apply constant fixes
        file_content = apply_constant_fixes(file_content);

        // 8. VTable conflict
        file_content = String.replace(file_content, "vtable :: (obj:", "get_vtable :: (obj:");

        // 9. std.string -> std.String
        file_content = String.replace(file_content, "std.string", "std.String");

        // 10. Comment out symbols not found in library
        file_content = filter_missing_symbols(file_content, symbols_filename);

        // Write final output
        write_success := write_entire_file(output_filename, file_content);
        if write_success {
            print("Successfully generated %\n", output_filename);
        } else {
            print("Failed to write %\n", output_filename);
        }

        // Clean up temp file
        // Note: Jai doesn't have a built-in delete_file, so we leave the temp file

    } else {
        print("Failed to generate bindings.\n");
    }
}

get_platform_header :: () -> string {
    #if IS_WINDOWS {
        return WINDOWS_HEADER;
    } else #if IS_LINUX {
        return LINUX_HEADER;
    } else #if IS_MACOS {
        return MACOS_HEADER;
    } else {
        return "";
    }
}

COMMON_HEADER :: #string END
#import "Basic";
#import "Math";

std :: struct {
    unique_ptr :: struct(T: Type, Deleter: Type=void) {
        ptr: *T;
    }
    array :: struct(T: Type, N: int) {
        data: [N] T;
    }
    false_type :: struct {}
    true_type :: struct {}
    integral_constant__RAW :: struct {}
    atomic :: struct(T: Type) { value: T; }
    byte :: u8;
    shared_ptr :: struct(T: Type) { ptr: *T; }
    optional :: struct(T: Type) { value: T; has_value: bool; }
    vector :: struct(T: Type) { ptr: *T; count: int; }
    tuple :: struct(T1: Type, T2: Type=void, T3: Type=void) {
        v1: T1;
        #if T2 != void { v2: T2; }
        #if T3 != void { v3: T3; }
    }
    String :: struct {}
    String_view :: struct {}
}

va_list :: *void;
SK_FloatInfinity :: FLOAT32_INFINITY;

UnknownTemplateArgumentPlaceholder :: void;
PlaceholderForUnsupportedArgument :: void;
enable_if_t :: struct(T: Type) {};

// =============================================================================
// sk_sp<T> FFI Helpers
// =============================================================================
//
// WARNING: Functions that take sk_sp<T> by value have broken FFI semantics.
// The value gets corrupted when passed from Jai to C++ due to ABI differences
// in how single-pointer structs are passed (registers vs stack).
//
// Use the *_safe wrapper functions or manually set fPtr fields instead.
//
// Affected functions include:
// - SkFont.Constructor(sk_sp<SkTypeface>, ...)
// - SkFont.setTypeface(sk_sp<SkTypeface>)
// - SkPaint methods taking sk_sp<SkShader>, sk_sp<SkColorFilter>, etc.
// - Any function with sk_sp<T> parameter (not pointer to sk_sp)
// =============================================================================

// Reference counting helpers for sk_sp (ref/unref are inlined in C++ headers)
libskia_ref_helper :: #library "skia_ref_helper";
sk_ref_cnt_ref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_unref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_get_count :: (ptr: *void) -> s32 #foreign libskia_ref_helper;

// Helper to increment reference count for any SkRefCnt-derived type
sk_sp_ref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_ref(sp.fPtr);
    }
}

// Helper to decrement reference count for any SkRefCnt-derived type
sk_sp_unref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_unref(sp.fPtr);
        sp.fPtr = null;
    }
}

// Helper to reset an sk_sp to a new pointer (handles refcounting)
sk_sp_reset :: (sp: *$T/sk_sp, new_ptr: *T.element_type) {
    old_ptr := sp.fPtr;
    sp.fPtr = new_ptr;
    if new_ptr {
        sk_ref_cnt_ref(new_ptr);
    }
    if old_ptr {
        sk_ref_cnt_unref(old_ptr);
    }
}

// =============================================================================
// SkFont Safe Wrappers (work around sk_sp by-value ABI issue)
// =============================================================================

// Create an SkFont with a typeface and size, avoiding sk_sp by-value ABI issues
SkFont_make :: (typeface: *SkTypeface, size: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);  // Default constructor
    SkFont.setSize(*font, size);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

// Create an SkFont with a typeface, size, scale, and skew
SkFont_make :: (typeface: *SkTypeface, size: SkScalar, scaleX: SkScalar, skewX: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);  // Default constructor
    SkFont.setSize(*font, size);
    SkFont.setScaleX(*font, scaleX);
    SkFont.setSkewX(*font, skewX);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

// Set typeface on an SkFont without sk_sp by-value ABI issues
SkFont_setTypeface_safe :: (font: *SkFont, typeface: *SkTypeface) {
    // Increment refcount for the new typeface (we're sharing ownership)
    if typeface {
        sk_ref_cnt_ref(typeface);
    }
    // Decrement refcount for the old typeface
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
    }
    // Direct assignment to avoid sk_sp by-value ABI issue
    font.fTypeface.fPtr = typeface;
}

// Clean up an SkFont (decrement typeface refcount)
SkFont_destroy :: (font: *SkFont) {
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
        font.fTypeface.fPtr = null;
    }
}

END

WINDOWS_HEADER :: #string END
#import "Basic";
#import "Math";
#import "Windows";

libskia :: #library "skia";  // Jai appends .dll automatically

std :: struct {
    unique_ptr :: struct(T: Type, Deleter: Type=void) {
        ptr: *T;
    }
    array :: struct(T: Type, N: int) {
        data: [N] T;
    }
    false_type :: struct {}
    true_type :: struct {}
    integral_constant__RAW :: struct {}
    atomic :: struct(T: Type) { value: T; }
    byte :: u8;
    shared_ptr :: struct(T: Type) { ptr: *T; }
    optional :: struct(T: Type) { value: T; has_value: bool; }
    vector :: struct(T: Type) { ptr: *T; count: int; }
    tuple :: struct(T1: Type, T2: Type=void, T3: Type=void) {
        v1: T1;
        #if T2 != void { v2: T2; }
        #if T3 != void { v3: T3; }
    }
    String :: struct {}
    String_view :: struct {}
}

va_list :: *void;
FILE :: *void;  // Windows FILE handle
SK_FloatInfinity :: FLOAT32_INFINITY;

UnknownTemplateArgumentPlaceholder :: void;
PlaceholderForUnsupportedArgument :: void;
enable_if_t :: struct(T: Type) {};

// =============================================================================
// sk_sp<T> FFI Helpers
// =============================================================================
//
// WARNING: Functions that take sk_sp<T> by value have broken FFI semantics.
// The value gets corrupted when passed from Jai to C++ due to ABI differences
// in how single-pointer structs are passed (registers vs stack).
//
// Use the *_safe wrapper functions or manually set fPtr fields instead.
// =============================================================================

// Reference counting helpers for sk_sp (ref/unref are inlined in C++ headers)
libskia_ref_helper :: #library "skia_ref_helper";
sk_ref_cnt_ref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_unref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_get_count :: (ptr: *void) -> s32 #foreign libskia_ref_helper;

// Helper to increment reference count for any SkRefCnt-derived type
sk_sp_ref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_ref(sp.fPtr);
    }
}

// Helper to decrement reference count for any SkRefCnt-derived type
sk_sp_unref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_unref(sp.fPtr);
        sp.fPtr = null;
    }
}

// Helper to reset an sk_sp to a new pointer (handles refcounting)
sk_sp_reset :: (sp: *$T/sk_sp, new_ptr: *T.element_type) {
    old_ptr := sp.fPtr;
    sp.fPtr = new_ptr;
    if new_ptr {
        sk_ref_cnt_ref(new_ptr);
    }
    if old_ptr {
        sk_ref_cnt_unref(old_ptr);
    }
}

// =============================================================================
// SkFont Safe Wrappers (work around sk_sp by-value ABI issue)
// =============================================================================

SkFont_make :: (typeface: *SkTypeface, size: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, size);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

SkFont_make :: (typeface: *SkTypeface, size: SkScalar, scaleX: SkScalar, skewX: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, size);
    SkFont.setScaleX(*font, scaleX);
    SkFont.setSkewX(*font, skewX);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

SkFont_setTypeface_safe :: (font: *SkFont, typeface: *SkTypeface) {
    if typeface {
        sk_ref_cnt_ref(typeface);
    }
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
    }
    font.fTypeface.fPtr = typeface;
}

SkFont_destroy :: (font: *SkFont) {
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
        font.fTypeface.fPtr = null;
    }
}

// =============================================================================
// Custom Font Manager Creation (Windows mangled symbols)
// =============================================================================

SkFontMgr_New_Custom_Directory :: (path: *u8) -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "?SkFontMgr_New_Custom_Directory@@YA?AV?$sk_sp@VSkFontMgr@@@@PEBD@Z";
SkFontMgr_New_Custom_Empty :: () -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "?SkFontMgr_New_Custom_Empty@@YA?AV?$sk_sp@VSkFontMgr@@@@XZ";

END

LINUX_HEADER :: #string END
#import "Basic";
#import "Math";
#import "POSIX";

libskia :: #library "skia";

std :: struct {
    unique_ptr :: struct(T: Type, Deleter: Type=void) {
        ptr: *T;
    }
    array :: struct(T: Type, N: int) {
        data: [N] T;
    }
    false_type :: struct {}
    true_type :: struct {}
    integral_constant__RAW :: struct {}
    atomic :: struct(T: Type) { value: T; }
    byte :: u8;
    shared_ptr :: struct(T: Type) { ptr: *T; }
    optional :: struct(T: Type) { value: T; has_value: bool; }
    vector :: struct(T: Type) { ptr: *T; count: int; }
    tuple :: struct(T1: Type, T2: Type=void, T3: Type=void) {
        v1: T1;
        #if T2 != void { v2: T2; }
        #if T3 != void { v3: T3; }
    }
    String :: struct {}
    String_view :: struct {}
}

va_list :: *void;
// FILE is imported from POSIX
// S16_MAX, S32_MAX, S64_MAX, S32_MIN are from Math module

SK_FloatInfinity :: FLOAT32_INFINITY;

UnknownTemplateArgumentPlaceholder :: void;
PlaceholderForUnsupportedArgument :: void;
enable_if_t :: struct(T: Type) {};

// =============================================================================
// sk_sp<T> FFI Helpers
// =============================================================================
//
// WARNING: Functions that take sk_sp<T> by value have broken FFI semantics.
// The value gets corrupted when passed from Jai to C++ due to ABI differences
// in how single-pointer structs are passed (registers vs stack).
//
// Use the *_safe wrapper functions or manually set fPtr fields instead.
// =============================================================================

// Reference counting helpers for sk_sp (ref/unref are inlined in C++ headers)
libskia_ref_helper :: #library "skia_ref_helper";
sk_ref_cnt_ref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_unref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_get_count :: (ptr: *void) -> s32 #foreign libskia_ref_helper;

// Helper to increment reference count for any SkRefCnt-derived type
sk_sp_ref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_ref(sp.fPtr);
    }
}

// Helper to decrement reference count for any SkRefCnt-derived type
sk_sp_unref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_unref(sp.fPtr);
        sp.fPtr = null;
    }
}

// Helper to reset an sk_sp to a new pointer (handles refcounting)
sk_sp_reset :: (sp: *$T/sk_sp, new_ptr: *T.element_type) {
    old_ptr := sp.fPtr;
    sp.fPtr = new_ptr;
    if new_ptr {
        sk_ref_cnt_ref(new_ptr);
    }
    if old_ptr {
        sk_ref_cnt_unref(old_ptr);
    }
}

// =============================================================================
// SkFont Safe Wrappers (work around sk_sp by-value ABI issue)
// =============================================================================

SkFont_make :: (typeface: *SkTypeface, size: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, size);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

SkFont_make :: (typeface: *SkTypeface, size: SkScalar, scaleX: SkScalar, skewX: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, size);
    SkFont.setScaleX(*font, scaleX);
    SkFont.setSkewX(*font, skewX);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

SkFont_setTypeface_safe :: (font: *SkFont, typeface: *SkTypeface) {
    if typeface {
        sk_ref_cnt_ref(typeface);
    }
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
    }
    font.fTypeface.fPtr = typeface;
}

SkFont_destroy :: (font: *SkFont) {
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
        font.fTypeface.fPtr = null;
    }
}

// =============================================================================
// Custom Font Manager Creation (Linux mangled symbols)
// =============================================================================

SkFontMgr_New_Custom_Directory :: (path: *u8) -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "_Z30SkFontMgr_New_Custom_DirectoryPKc";
SkFontMgr_New_Custom_Empty :: () -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "_Z26SkFontMgr_New_Custom_Emptyv";
SkFontMgr_New_Custom_Data :: (data_span: SkSpan(sk_sp(SkData))) -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "_Z25SkFontMgr_New_Custom_Data6SkSpanI5sk_spI6SkDataEE";

END

MACOS_HEADER :: #string END
#import "Basic";
#import "Math";
#import "POSIX";

libskia :: #library "skia";

std :: struct {
    unique_ptr :: struct(T: Type, Deleter: Type=void) {
        ptr: *T;
    }
    array :: struct(T: Type, N: int) {
        data: [N] T;
    }
    false_type :: struct {}
    true_type :: struct {}
    integral_constant__RAW :: struct {}
    atomic :: struct(T: Type) { value: T; }
    byte :: u8;
    shared_ptr :: struct(T: Type) { ptr: *T; }
    optional :: struct(T: Type) { value: T; has_value: bool; }
    vector :: struct(T: Type) { ptr: *T; count: int; }
    tuple :: struct(T1: Type, T2: Type=void, T3: Type=void) {
        v1: T1;
        #if T2 != void { v2: T2; }
        #if T3 != void { v3: T3; }
    }
    String :: struct {}
    String_view :: struct {}
}

va_list :: *void;
SK_FloatInfinity :: FLOAT32_INFINITY;

UnknownTemplateArgumentPlaceholder :: void;
PlaceholderForUnsupportedArgument :: void;
enable_if_t :: struct(T: Type) {};

// Reference counting helpers
libskia_ref_helper :: #library "skia_ref_helper";
sk_ref_cnt_ref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_unref :: (ptr: *void) -> void #foreign libskia_ref_helper;
sk_ref_cnt_get_count :: (ptr: *void) -> s32 #foreign libskia_ref_helper;

sk_sp_ref :: (sp: *$T/sk_sp) {
    if sp.fPtr sk_ref_cnt_ref(sp.fPtr);
}

sk_sp_unref :: (sp: *$T/sk_sp) {
    if sp.fPtr {
        sk_ref_cnt_unref(sp.fPtr);
        sp.fPtr = null;
    }
}

sk_sp_reset :: (sp: *$T/sk_sp, new_ptr: *T.element_type) {
    old_ptr := sp.fPtr;
    sp.fPtr = new_ptr;
    if new_ptr sk_ref_cnt_ref(new_ptr);
    if old_ptr sk_ref_cnt_unref(old_ptr);
}

SkFont_make :: (typeface: *SkTypeface, size: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, size);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

SkFont_make :: (typeface: *SkTypeface, size: SkScalar, scaleX: SkScalar, skewX: SkScalar) -> SkFont {
    font: SkFont;
    SkFont.Constructor(*font);
    SkFont.setSize(*font, size);
    SkFont.setScaleX(*font, scaleX);
    SkFont.setSkewX(*font, skewX);
    SkFont_setTypeface_safe(*font, typeface);
    return font;
}

SkFont_setTypeface_safe :: (font: *SkFont, typeface: *SkTypeface) {
    if typeface sk_ref_cnt_ref(typeface);
    if font.fTypeface.fPtr sk_ref_cnt_unref(font.fTypeface.fPtr);
    font.fTypeface.fPtr = typeface;
}

SkFont_destroy :: (font: *SkFont) {
    if font.fTypeface.fPtr {
        sk_ref_cnt_unref(font.fTypeface.fPtr);
        font.fTypeface.fPtr = null;
    }
}

// macOS uses same mangling as Linux (Itanium ABI)
SkFontMgr_New_Custom_Directory :: (path: *u8) -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "_Z30SkFontMgr_New_Custom_DirectoryPKc";
SkFontMgr_New_Custom_Empty :: () -> sk_sp(SkFontMgr) #cpp_return_type_is_non_pod #foreign libskia "_Z26SkFontMgr_New_Custom_Emptyv";

END

apply_operator_renames :: (content: string) -> string {
    result := content;
    // Order matters - compound operators first, then single-char operators
    result = String.replace(result, "operator+=", "operator_plus_equals");
    result = String.replace(result, "operator-=", "operator_minus_equals");
    result = String.replace(result, "operator*=", "operator_mul_equals");
    result = String.replace(result, "operator/=", "operator_div_equals");
    result = String.replace(result, "operator==", "operator_eq");
    result = String.replace(result, "operator!=", "operator_neq");
    result = String.replace(result, "operator[]", "operator_subscript");
    result = String.replace(result, "operator<", "operator_less");
    // Rename declarations (with ::)
    result = String.replace(result, "operator+ ::", "operator_plus ::");
    result = String.replace(result, "operator- ::", "operator_minus ::");
    result = String.replace(result, "operator* ::", "operator_mul ::");
    result = String.replace(result, "operator/ ::", "operator_div ::");
    // Rename calls (with parentheses)
    result = String.replace(result, "operator+(", "operator_plus(");
    result = String.replace(result, "operator-(", "operator_minus(");
    result = String.replace(result, "operator*(", "operator_mul(");
    result = String.replace(result, "operator/(", "operator_div(");
    return result;
}

apply_struct_fixes :: (content: string) -> string {
    result := content;
    result = String.replace(result, "fImageFilters:    skia_private.STArray(1, sk_sp(SkImageFilter));", "fImageFilters:    skia_private.STArray(1, sk_sp(SkImageFilter), true);");
    result = String.replace(result, "sk_has_trivially_relocatable_member :: struct(: Type, _1: Type)", "sk_has_trivially_relocatable_member :: struct(T: Type, _1: Type)");
    result = String.replace(result, "using,except(, _1)", "using,except(_1)");
    result = String.replace(result, "sk_has_trivially_relocatable_member__RAW(, _1)", "sk_has_trivially_relocatable_member__RAW(T, _1)");
    result = String.replace(result, "sk_has_trivially_relocatable_member__RAW :: struct(: Type, _1: Type)", "sk_has_trivially_relocatable_member__RAW :: struct(T: Type, _1: Type)");
    result = String.replace(result, "AutoTMalloc :: struct(T: Type, : Type =", "AutoTMalloc :: struct(T: Type, _1: Type =");
    result = String.replace(result, "AutoSTMalloc :: struct(kCountRequested: u64, T: Type, : Type =", "AutoSTMalloc :: struct(kCountRequested: u64, T: Type, _1: Type =");
    result = String.replace(result, "UnknownTemplateArgumentPlaceholder, T", "Nreq, T");
    result = String.replace(result, "SkOverloadedFunctionObject :: struct(T: Type, P: *T)", "SkOverloadedFunctionObject :: struct(T: Type, P: Type)");
    result = String.replace(result, "SkOverloadedFunctionObject__RAW :: struct(T: Type, P: *T)", "SkOverloadedFunctionObject__RAW :: struct(T: Type, P: Type)");
    return result;
}

apply_enum_fixes :: (content: string) -> string {
    result := content;
    result = String.replace(result, "RescaleGamma :: enum bool", "RescaleGamma :: enum u8");
    result = String.replace(result, "Src    :: false;", "Src    :: 0;");
    result = String.replace(result, "Linear :: true;", "Linear :: 1;");
    result = String.replace(result, "Type :: enum bool", "Type :: enum u8");
    result = String.replace(result, "Arc   :: false;", "Arc   :: 0;");
    result = String.replace(result, "Wedge :: true;", "Wedge :: 1;");
    return result;
}

apply_syntax_fixes :: (content: string) -> string {
    result := content;
    result = String.replace(result, "fState: std.atomic(u8) = xx State.NotStarted;", "fState: std.atomic(u8) = .{cast(u8)State.NotStarted};");
    result = String.replace(result, "SK_INIT_TO_AVOID_WARNING :: = 0;", "SK_INIT_TO_AVOID_WARNING :: 0;");
    result = String.replace(result, "fClosePointStorage: std.array(SkPoint, 2) = 2;", "fClosePointStorage: std.array(SkPoint, 2);");
    result = String.replace(result, "fStorage:      std.array(SkPoint, 4) = 4;", "fStorage:      std.array(SkPoint, 4);");
    return result;
}

apply_constant_fixes :: (content: string) -> string {
    result := content;
    result = String.replace(result,
        "kORableMasks:               s32 : xx TypeMask.Translate_Mask | xx TypeMask.Scale_Mask | xx TypeMask.Affine_Mask | xx TypeMask.Perspective_Mask;",
        "kORableMasks:               s32 : 15; // Translate(1) | Scale(2) | Affine(4) | Perspective(8)");
    result = String.replace(result,
        "kAllMasks:                  s32 : xx TypeMask.Translate_Mask | xx TypeMask.Scale_Mask | xx TypeMask.Affine_Mask | xx TypeMask.Perspective_Mask | kRectStaysRect_Mask;",
        "kAllMasks:                  s32 : 31; // kORableMasks(15) | kRectStaysRect(16)");
    result = String.replace(result, "kSkBlendModeCount: s32 : xx SkBlendMode.LastMode + 1;", "kSkBlendModeCount: s32 : cast(s32) (SkBlendMode.LastMode + 1);");
    result = String.replace(result, "kSkColorTypeCnt: s32 : xx SkColorType.LastEnum_SkColorType + 1;", "kSkColorTypeCnt: s32 : cast(s32) (SkColorType.LastEnum_SkColorType + 1);");
    result = String.replace(result, "kSkFilterModeCount: s32 : xx SkFilterMode.Last + 1;", "kSkFilterModeCount: s32 : cast(s32) (SkFilterMode.Last + 1);");
    result = String.replace(result, "kSkMipmapModeCount: s32 : xx SkMipmapMode.Last + 1;", "kSkMipmapModeCount: s32 : cast(s32) (SkMipmapMode.Last + 1);");
    result = String.replace(result, "kSkTileModeCount: s32 : xx SkTileMode.LastTileMode + 1;", "kSkTileModeCount: s32 : cast(s32) (SkTileMode.LastTileMode + 1);");
    result = String.replace(result, "kStyleCount:                 s32 : xx Style.StrokeAndFill_Style + 1;", "kStyleCount:                 s32 : cast(s32) (Style.StrokeAndFill_Style + 1);");
    result = String.replace(result, "kCapCount:                   s32 : xx Cap.Last_Cap + 1;", "kCapCount:                   s32 : cast(s32) (Cap.Last_Cap + 1);");
    result = String.replace(result, "kJoinCount:                  s32 : xx Join.Last_Join + 1;", "kJoinCount:                  s32 : cast(s32) (Join.Last_Join + 1);");
    return result;
}

filter_missing_symbols :: (content: string, symbols_filename: string) -> string {
    symbols_content, symbols_read_success := read_entire_file(symbols_filename);
    valid_symbols: Table(string, bool);

    if symbols_read_success {
        symbol_lines := String.split(symbols_content, "\n");
        for symbol_lines {
            trimmed := String.trim(it);
            if trimmed.count > 0 {
                table_add(*valid_symbols, trimmed, true);
            }
        }
        print("Loaded % valid symbols from %\n", valid_symbols.count, symbols_filename);
    } else {
        print("Warning: Could not load %, skipping symbol filtering\n", symbols_filename);
        return content;
    }

    lines := String.split(content, "\n");
    builder: String_Builder;
    commented_count := 0;

    for lines {
        should_comment := false;

        // Check if line has a #foreign libskia declaration (but not libskia_ref_helper)
        if String.contains(it, "#foreign libskia") && !String.contains(it, "#foreign libskia_ref_helper") {
            // Try to extract quoted symbol name (mangled symbols)
            quote_start := String.find_index_from_left(it, "#foreign libskia \"");
            if quote_start != -1 {
                symbol_start := quote_start + 18; // length of "#foreign libskia \""
                remaining := String.slice(it, symbol_start, it.count - symbol_start);
                quote_end := String.find_index_from_left(remaining, "\"");
                if quote_end != -1 {
                    symbol := String.slice(remaining, 0, quote_end);
                    if !table_find_pointer(*valid_symbols, symbol) {
                        should_comment = true;
                        commented_count += 1;
                    }
                }
            } else {
                // Non-quoted symbol (C-style)
                trimmed := String.trim_left(it);
                space_pos := String.find_index_from_left(trimmed, " ");
                if space_pos > 0 {
                    func_name := String.slice(trimmed, 0, space_pos);
                    if !table_find_pointer(*valid_symbols, func_name) {
                        should_comment = true;
                        commented_count += 1;
                    }
                }
            }
        }

        if should_comment {
            append(*builder, "// ");
        }
        append(*builder, it);
        append(*builder, "\n");
    }

    print("Commented out % unresolved foreign symbols\n", commented_count);
    return builder_to_string(*builder);
}
