const std = @import("std");
const Parser = @import("parser.zig").Parser;
const File = std.fs.File;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn usage(file: File) !void {
    _ = try file.write("Usage:\n");
    _ = try file.write("    <exename> <inputfile>\n");
}

pub fn main() !void {
    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut();

    _ = try stdout.write("\n");
    defer _ = stdout.write("\n") catch 0;

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

    var parser = try Parser.init(input, allocator);
    defer parser.deinit();

    while (true) {
        const token = try parser.next();
        std.log.info("{any}", .{token.kind});
        if (token.kind == .EOF) {
            break;
        }
    }
}
