#import "Basic";
#import "Compiler";
#import "Process";
#import "File_Utilities";

#run {
    set_build_options_dc(.{do_output=false});

    // Build the sk_sp helper library if needed
    #if OS == .WINDOWS {
        helper_lib := "skia_ref_helper.dll";
        helper_src := "skia_ref_helper.cpp";

        need_rebuild := !file_exists(helper_lib);

        if need_rebuild {
            print("Building skia_ref_helper library for Windows...\n");

            // Try to compile with clang-cl (preferred)
            // Using LLVM/Clang which is installed based on build_skia.bat
            compile_result := run_command(
                "C:/Program Files/LLVM/bin/clang-cl.exe",
                "/LD", "/O2", "/EHsc",
                "skia_ref_helper.cpp",
                "/Fe:skia_ref_helper.dll",
                "/link", "/DLL"
            );

            if compile_result.exit_code != 0 {
                print("Clang-cl failed (exit code %), trying MSVC cl.exe...\n", compile_result.exit_code);
                // Fallback to MSVC cl.exe via Developer Command Prompt
                compile_result = run_command(
                    "cl",
                    "/LD", "/O2", "/EHsc",
                    "skia_ref_helper.cpp",
                    "/Fe:skia_ref_helper.dll"
                );
            }

            if compile_result.exit_code != 0 {
                print("Error: Failed to compile skia_ref_helper.cpp\n");
                print("Please ensure LLVM or Visual Studio is installed.\n");
                return;
            }

            print("Successfully built %\n", helper_lib);
        }

    } else #if OS == .LINUX {
        helper_lib := "skia_ref_helper.so";
        helper_src := "skia_ref_helper.cpp";

        need_rebuild := !file_exists(helper_lib);

        if need_rebuild {
            print("Building skia_ref_helper library for Linux...\n");

            compile_result := run_command("g++", "-shared", "-fPIC", "-O2", "-o", helper_lib, helper_src);
            if compile_result.exit_code != 0 {
                print("Error: Failed to compile skia_ref_helper.cpp\n");
                return;
            }

            print("Successfully built %\n", helper_lib);
        }

    } else #if OS == .MACOS {
        helper_lib := "skia_ref_helper.dylib";
        helper_src := "skia_ref_helper.cpp";

        need_rebuild := !file_exists(helper_lib);

        if need_rebuild {
            print("Building skia_ref_helper library for macOS...\n");

            compile_result := run_command("clang++", "-shared", "-fPIC", "-O2", "-o", helper_lib, helper_src);
            if compile_result.exit_code != 0 {
                print("Error: Failed to compile skia_ref_helper.cpp\n");
                return;
            }

            print("Successfully built %\n", helper_lib);
        }
    }

    w := compiler_create_workspace("Example");

    options := get_build_options(w);
    options.output_executable_name = "example";

    import_path: [..] string;
    array_add(*import_path, ..options.import_path);
    array_add(*import_path, ".");
    options.import_path = import_path;

    #if OS == .WINDOWS {
        // On Windows, we need to link against the import library
        linker_args: [..] string;
        array_add(*linker_args, ..options.additional_linker_arguments);
        array_add(*linker_args, "skia.dll.lib");
        array_add(*linker_args, "skia_ref_helper.lib");
        options.additional_linker_arguments = linker_args;
    } else {
        linker_args: [..] string;
        array_add(*linker_args, ..options.additional_linker_arguments);
        array_add(*linker_args, "-L.");
        options.additional_linker_arguments = linker_args;
    }

    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("example.jai", w);

    while true {
        message := compiler_wait_for_message();
        if !message break;
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(w);
}
