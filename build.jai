#import "Basic";
#import "Compiler";
#import "Process";
#import "File_Utilities";

#run {
    set_build_options_dc(.{do_output=false});

    // Build the sk_sp helper library if needed
    helper_lib := "skia_ref_helper.so";
    helper_src := "skia_ref_helper.cpp";

    // Check if we need to rebuild the helper library
    need_rebuild := !file_exists(helper_lib);

    if need_rebuild {
        print("Building skia_ref_helper library...\n");

        // Compile the C++ helper to shared library
        compile_result := run_command("g++", "-shared", "-fPIC", "-O2", "-o", helper_lib, helper_src);
        if compile_result.exit_code != 0 {
            print("Error: Failed to compile skia_ref_helper.cpp\n");
            return;
        }

        print("Successfully built %\n", helper_lib);
    }

    w := compiler_create_workspace("Example");

    options := get_build_options(w);
    options.output_executable_name = "example";

    import_path: [..] string;
    array_add(*import_path, ..options.import_path);
    array_add(*import_path, ".");
    options.import_path = import_path;

    linker_args: [..] string;
    array_add(*linker_args, ..options.additional_linker_arguments);
    array_add(*linker_args, "-L.");
    options.additional_linker_arguments = linker_args;

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
