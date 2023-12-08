const std = @import("std");
const parser = @import("parser.zig");
const File = std.fs.File;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const LOGGING = false;

fn usage(file: File) !void {
    _ = try file.write("Usage:\n");
    _ = try file.write("    <exename> <inputfile>\n");
}

pub fn main() !void {
    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut();

    _ = try stdout.write("\nBegin\n\n");
    defer _ = stdout.write("\nEnd\n") catch 0;

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.log.err("Incorrect usage!", .{});
        try usage(stderr);
        return;
    }

    const inputfilename = args[1];
    const inputfile = try std.fs.cwd().openFile(inputfilename, .{});
    const metadata = try inputfile.metadata();
    const size = metadata.size();

    var input = try allocator.alloc(u8, size);
    defer allocator.free(input);

    const bytesRead = try inputfile.read(input);
    try std.testing.expect(bytesRead == size);

    var tokenList = std.ArrayList(parser.Token).init(allocator);
    var _parser = try parser.Parser.init(input, tokenList, allocator);
    defer _parser.deinit();

    while (true) {
        const expr = if (try _parser.expr()) |expr| expr else {
            break;
        };
        const writer = stdout.writer();
        try expr.serialize(writer);

        if ((try _parser.next()).kind == .EOF) {
            break;
        }
    }
}
