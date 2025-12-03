#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
String :: #import "String";
#import "File";
#import "Hash_Table";


#run {
    set_build_options_dc(.{do_output=false});

    options: Generate_Bindings_Options;
    array_add(*options.source_files, "wrapper.h");
    
    // Include path for Skia
    array_add(*options.include_paths, "skia");
    
    // System include paths (mimic GCC default search list)
    array_add(*options.system_include_paths, "/usr/include/c++/13");
    array_add(*options.system_include_paths, "/usr/include/x86_64-linux-gnu/c++/13");
    array_add(*options.system_include_paths, "/usr/include/c++/13/backward");
    array_add(*options.system_include_paths, "/usr/lib/gcc/x86_64-linux-gnu/13/include");
    array_add(*options.system_include_paths, "/usr/local/include");
    array_add(*options.system_include_paths, "/usr/include/x86_64-linux-gnu");
    array_add(*options.system_include_paths, "/usr/include");

    // Clang arguments for C++ parsing
    array_add(*options.extra_clang_arguments, "-x", "c++", "-std=c++17");
    array_add(*options.extra_clang_arguments, "-DSK_BUILD_FOR_UNIX");
    
    // option.libraries requires the lib to exist. We skip it and force generation.
    options.strip_flags = 0; 
    options.generate_compile_time_struct_checks = false; 

    print("Generating bindings for Skia...\n");
    success := generate_bindings(options, "skia.jai");
    
    if success {
        print("Post-processing skia.jai...\n");
        file_content, read_success := read_entire_file("skia.jai");
        if !read_success {
            print("Error reading generated file.\n");
            return;
        }
        
        // 1. Replace unknown library with libskia
        file_content = String.replace(file_content, "#foreign __UnknownLib", "#foreign libskia");

        // 2. Prepend header with module parameters, imports, and std struct definitions
        header := #string END
#module_parameters (lib_name := "skia");

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

S16_MAX :: 32767;
S32_MAX :: 2147483647;
S64_MAX :: 9223372036854775807;
S32_MIN :: -2147483648;

SK_FloatInfinity :: FLOAT32_INFINITY;

UnknownTemplateArgumentPlaceholder :: void;
PlaceholderForUnsupportedArgument :: void;
enable_if_t :: struct(T: Type) {};

END

        // Prepend header to file content
        file_content = tprint("%\n%", header, file_content);

        // 3. Rename operators (both declarations and calls)
        // Note: Order matters - compound operators first, then single-char operators
        file_content = String.replace(file_content, "operator+=", "operator_plus_equals");
        file_content = String.replace(file_content, "operator-=", "operator_minus_equals");
        file_content = String.replace(file_content, "operator*=", "operator_mul_equals");
        file_content = String.replace(file_content, "operator/=", "operator_div_equals");
        file_content = String.replace(file_content, "operator==", "operator_eq");
        file_content = String.replace(file_content, "operator!=", "operator_neq");
        file_content = String.replace(file_content, "operator[]", "operator_subscript");
        file_content = String.replace(file_content, "operator<", "operator_less");
        // Rename declarations (with ::)
        file_content = String.replace(file_content, "operator+ ::", "operator_plus ::");
        file_content = String.replace(file_content, "operator- ::", "operator_minus ::");
        file_content = String.replace(file_content, "operator* ::", "operator_mul ::");
        file_content = String.replace(file_content, "operator/ ::", "operator_div ::");
        // Rename calls (with parentheses)
        file_content = String.replace(file_content, "operator+(", "operator_plus(");
        file_content = String.replace(file_content, "operator-(", "operator_minus(");
        file_content = String.replace(file_content, "operator*(", "operator_mul(");
        file_content = String.replace(file_content, "operator/(", "operator_div(");

        // 4. Struct Fixes
        // ... existing fixes ...
        file_content = String.replace(file_content, "fImageFilters:    skia_private.STArray(1, sk_sp(SkImageFilter));", "fImageFilters:    skia_private.STArray(1, sk_sp(SkImageFilter), true);");
        // sk_has_trivially_relocatable_member
        file_content = String.replace(file_content, "sk_has_trivially_relocatable_member :: struct(: Type, _1: Type)", "sk_has_trivially_relocatable_member :: struct(T: Type, _1: Type)");
        file_content = String.replace(file_content, "using,except(, _1)", "using,except(_1)"); // FIX: Remove leading comma
        file_content = String.replace(file_content, "sk_has_trivially_relocatable_member__RAW(, _1)", "sk_has_trivially_relocatable_member__RAW(T, _1)");
        file_content = String.replace(file_content, "sk_has_trivially_relocatable_member__RAW :: struct(: Type, _1: Type)", "sk_has_trivially_relocatable_member__RAW :: struct(T: Type, _1: Type)");

        file_content = String.replace(file_content, "AutoTMalloc :: struct(T: Type, : Type =", "AutoTMalloc :: struct(T: Type, _1: Type =");
        file_content = String.replace(file_content, "AutoSTMalloc :: struct(kCountRequested: u64, T: Type, : Type =", "AutoSTMalloc :: struct(kCountRequested: u64, T: Type, _1: Type =");

        file_content = String.replace(file_content, "UnknownTemplateArgumentPlaceholder, T", "Nreq, T"); // For STArray

        file_content = String.replace(file_content, "SkOverloadedFunctionObject :: struct(T: Type, P: *T)", "SkOverloadedFunctionObject :: struct(T: Type, P: Type)");
        file_content = String.replace(file_content, "SkOverloadedFunctionObject__RAW :: struct(T: Type, P: *T)", "SkOverloadedFunctionObject__RAW :: struct(T: Type, P: Type)");

        // 5. Enum Fixes
        file_content = String.replace(file_content, "RescaleGamma :: enum bool", "RescaleGamma :: enum u8");
        file_content = String.replace(file_content, "Src    :: false;", "Src    :: 0;");
        file_content = String.replace(file_content, "Linear :: true;", "Linear :: 1;");

        file_content = String.replace(file_content, "Type :: enum bool", "Type :: enum u8"); // SkArc
        file_content = String.replace(file_content, "Arc   :: false;", "Arc   :: 0;");
        file_content = String.replace(file_content, "Wedge :: true;", "Wedge :: 1;");

        // 6. Atomic Initialization
        file_content = String.replace(file_content, "fState: std.atomic(u8) = xx State.NotStarted;", "fState: std.atomic(u8) = .{cast(u8)State.NotStarted};");

        // 7. Syntax Fixes
        file_content = String.replace(file_content, "SK_INIT_TO_AVOID_WARNING :: = 0;", "SK_INIT_TO_AVOID_WARNING :: 0;");
        file_content = String.replace(file_content, "fClosePointStorage: std.array(SkPoint, 2) = 2;", "fClosePointStorage: std.array(SkPoint, 2);");
        file_content = String.replace(file_content, "fStorage:      std.array(SkPoint, 4) = 4;", "fStorage:      std.array(SkPoint, 4);");

        // 8. Type Casting Constants
        file_content = String.replace(file_content,
            "kORableMasks:               s32 : xx TypeMask.Translate_Mask | xx TypeMask.Scale_Mask | xx TypeMask.Affine_Mask | xx TypeMask.Perspective_Mask;",
            "kORableMasks:               s32 : 15; // Translate(1) | Scale(2) | Affine(4) | Perspective(8)");
        file_content = String.replace(file_content,
            "kAllMasks:                  s32 : xx TypeMask.Translate_Mask | xx TypeMask.Scale_Mask | xx TypeMask.Affine_Mask | xx TypeMask.Perspective_Mask | kRectStaysRect_Mask;",
            "kAllMasks:                  s32 : 31; // kORableMasks(15) | kRectStaysRect(16)");

        file_content = String.replace(file_content, "kSkBlendModeCount: s32 : xx SkBlendMode.LastMode + 1;", "kSkBlendModeCount: s32 : cast(s32) (SkBlendMode.LastMode + 1);");
        file_content = String.replace(file_content, "kSkColorTypeCnt: s32 : xx SkColorType.LastEnum_SkColorType + 1;", "kSkColorTypeCnt: s32 : cast(s32) (SkColorType.LastEnum_SkColorType + 1);");
        file_content = String.replace(file_content, "kSkFilterModeCount: s32 : xx SkFilterMode.Last + 1;", "kSkFilterModeCount: s32 : cast(s32) (SkFilterMode.Last + 1);");
        file_content = String.replace(file_content, "kSkMipmapModeCount: s32 : xx SkMipmapMode.Last + 1;", "kSkMipmapModeCount: s32 : cast(s32) (SkMipmapMode.Last + 1);");
        file_content = String.replace(file_content, "kSkTileModeCount: s32 : xx SkTileMode.LastTileMode + 1;", "kSkTileModeCount: s32 : cast(s32) (SkTileMode.LastTileMode + 1);");
        file_content = String.replace(file_content, "kStyleCount:                 s32 : xx Style.StrokeAndFill_Style + 1;", "kStyleCount:                 s32 : cast(s32) (Style.StrokeAndFill_Style + 1);");
        file_content = String.replace(file_content, "kCapCount:                   s32 : xx Cap.Last_Cap + 1;", "kCapCount:                   s32 : cast(s32) (Cap.Last_Cap + 1);");
        file_content = String.replace(file_content, "kJoinCount:                  s32 : xx Join.Last_Join + 1;", "kJoinCount:                  s32 : cast(s32) (Join.Last_Join + 1);");

        // 9. VTable conflict
        file_content = String.replace(file_content, "vtable :: (obj:", "get_vtable :: (obj:");

        // 10. std.string -> std.String
        file_content = String.replace(file_content, "std.string", "std.String");

        // 11. Comment out symbols not found in libskia.so
        // Load exported symbols from libskia_symbols.txt
        symbols_content, symbols_read_success := read_entire_file("libskia_symbols.txt");
        valid_symbols: Table(string, bool);
        if symbols_read_success {
            symbol_lines := String.split(symbols_content, "\n");
            for symbol_lines {
                trimmed := String.trim(it);
                if trimmed.count > 0 {
                    table_add(*valid_symbols, trimmed, true);
                }
            }
            print("Loaded % valid symbols from libskia_symbols.txt\n", valid_symbols.count);
        } else {
            print("Warning: Could not load libskia_symbols.txt, only commenting out _ZL symbols\n");
        }

        lines := String.split(file_content, "\n");
        builder: String_Builder;
        commented_count := 0;
        for lines {
            should_comment := false;

            // Check if line has a #foreign libskia declaration
            if String.contains(it, "#foreign libskia") {
                // Try to extract quoted symbol name (mangled symbols like "_Z...")
                quote_start := String.find_index_from_left(it, "#foreign libskia \"");
                if quote_start != -1 {
                    symbol_start := quote_start + 18; // length of "#foreign libskia \""
                    remaining := String.slice(it, symbol_start, it.count - symbol_start);
                    quote_end := String.find_index_from_left(remaining, "\"");
                    if quote_end != -1 {
                        symbol := String.slice(remaining, 0, quote_end);
                        // Check if symbol exists in valid_symbols table
                        if !table_find_pointer(*valid_symbols, symbol) {
                            should_comment = true;
                            commented_count += 1;
                        }
                    }
                } else {
                    // Non-quoted symbol (C-style like "skcms_foo")
                    // Pattern: "func_name :: (...) -> ... #foreign libskia;"
                    // Extract function name at start of line
                    trimmed := String.trim_left(it);
                    space_pos := String.find_index_from_left(trimmed, " ");
                    if space_pos > 0 {
                        func_name := String.slice(trimmed, 0, space_pos);
                        // Check if this is a plain C symbol (no mangling)
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
        final_content := builder_to_string(*builder);
        
        write_success := write_entire_file("skia.jai", final_content);
        if write_success {
            print("Successfully generated and patched skia.jai\n");
        } else {
            print("Failed to write patched file.\n");
        }
    } else {
        print("Failed to generate bindings.\n");
    }
}
