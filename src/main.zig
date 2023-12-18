const std = @import("std");
const parser = @import("parser.zig");
const File = std.fs.File;
const Allocator = std.mem.Allocator;

pub const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{});
var gpa = GeneralPurposeAllocator{};

pub var args: [][:0]u8 = undefined;

fn usage(file: File) !void {
    const writer = file.writer();
    try writer.print("Usage:\n\t{s} <inputfile>\n", .{args[0]});
}

pub fn main() !void {
    const stderr = std.io.getStdErr();
    _ = stderr;
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    const iStream = stdin.reader();
    const oStream = stdout.writer();

    _ = try stdout.write("\nBegin\n\n");
    defer _ = stdout.write("\nEnd\n") catch 0;

    const allocator = gpa.allocator();
    // args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    // if (args.len != 2) {
    //     std.log.err("Incorrect usage!", .{});
    //     try usage(stderr);
    //     return;
    // }

    // const inputfilename = args[1];
    // const inputfile = try std.fs.cwd().openFile(inputfilename, .{});
    // const metadata = try inputfile.metadata();
    // const size = metadata.size();

    // var input = try allocator.alloc(u8, size);
    // defer allocator.free(input);

    // const bytesRead = try inputfile.read(input);
    // try std.testing.expect(bytesRead == size);

    outer: while (true) {
        var input = std.ArrayList(u8).init(allocator);
        try oStream.print("\n> ", .{});
        try iStream.streamUntilDelimiter(input.writer(), '\n', null);

        var tokenList = std.ArrayList(parser.Token).init(allocator);
        var _parser = try parser.Parser.init(input.items, tokenList, allocator);
        defer _parser.deinit();

        const writer = stdout.writer();
        while (true) {
            const expr = if (_parser.expr() catch continue :outer) |expr| expr else {
                break;
            };

            try writer.print("\toriginal: {srl}\n", .{expr});
            const beta_reduced = try expr.beta_reduce(allocator);
            try writer.print("\treduced: {wr}\n", .{beta_reduced});

            if ((try _parser.next()).kind == .EOF) {
                break;
            }
        }
    }
}
