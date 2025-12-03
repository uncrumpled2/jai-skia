#import "Basic";
#import "Compiler";

#run {
    set_build_options_dc(.{do_output=false});

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
