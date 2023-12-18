const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

const Location = @import("parser.zig").Location;

const Identifier = Location;
const Abstraction = struct {
    of: Identifier,
    over: *Expression,
};
const Application = struct {
    of: *Expression,
    to: *Expression,
};

pub const Expression = struct {
    const ExpressionKind = union(enum) {
        Identifier,
        Abstraction: Abstraction,
        Application: Application,
    };

    kind: ExpressionKind,
    loc: Location,

    const Self = @This();

    // pub fn init(allocator: Allocator) !*Self {
    //     return try allocator.create(Self);
    // }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .Identifier => {
                allocator.destroy(self);
            },
            .Abstraction => |abs| {
                const over = abs.over;
                defer over.deinit();

                allocator.destroy(self);
            },
            .Application => |app| {
                const of = app.of;
                defer of.deinit();

                const to = app.to;
                defer to.deinit();

                allocator.destroy(self);
            },
        }
    }

    fn lexeme(self: *const Self) []const u8 {
        return self.loc.lexeme();
    }

    pub fn deep_copy(self: *const Self, allocator: Allocator) !*Self {
        switch (self.kind) {
            .Identifier => {
                const ident = try allocator.create(Self);
                ident.* = self.*;
                return ident;
            },
            .Abstraction => |abs| {
                const new_abs = try allocator.create(Self);
                new_abs.* = .{
                    .kind = .{ .Abstraction = .{
                        .of = abs.of,
                        .over = try abs.over.deep_copy(allocator),
                    } },
                    .loc = self.loc,
                };
                return new_abs;
            },
            .Application => |app| {
                const new_app = try allocator.create(Self);
                new_app.* = .{
                    .kind = .{ .Application = .{
                        .of = try app.of.deep_copy(allocator),
                        .to = try app.to.deep_copy(allocator),
                    } },
                    .loc = self.loc,
                };
                return new_app;
            },
        }
    }

    fn replace(self: *const Self, target: Identifier, with: *const Expression, allocator: Allocator) !*Expression {
        switch (self.kind) {
            .Identifier => {
                if (std.mem.eql(u8, self.lexeme(), target.lexeme())) {
                    return try with.deep_copy(allocator);
                } else {
                    return try self.deep_copy(allocator);
                }
            },
            .Abstraction => |abs| {
                const replaced = try abs.over.replace(target, with, allocator);
                const result = try allocator.create(Self);
                result.* = .{
                    .kind = .{ .Abstraction = .{
                        .of = abs.of,
                        .over = replaced,
                    } },
                    .loc = Location.NULL,
                };
                return result;
            },
            .Application => |app| {
                const result = try allocator.create(Self);
                result.* = .{
                    .kind = .{ .Application = .{
                        .of = try app.of.replace(target, with, allocator),
                        .to = try app.to.replace(target, with, allocator),
                    } },
                    .loc = Location.NULL,
                };
                return result;
            },
        }
    }

    pub fn beta_reduce(self: *const Self, allocator: Allocator) !*Expression {
        switch (self.kind) {
            .Application => |app| switch (app.of.kind) {
                .Abstraction => |abs| {
                    return try abs.over.replace(abs.of, app.to, allocator);
                },
                else => {
                    const reduced = try allocator.create(Self);
                    reduced.* = .{
                        .kind = .{ .Application = .{
                            .of = try app.of.beta_reduce(allocator),
                            .to = try app.to.beta_reduce(allocator),
                        } },
                        .loc = Location.NULL,
                    };
                    return reduced;
                },
            },
            else => {
                return try self.deep_copy(allocator);
            },
        }
    }

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        if (std.mem.eql(u8, fmt, "srl")) {
            try value.serialize(writer);
        } else if (std.mem.eql(u8, fmt, "wr")) {
            try value.write(writer);
        } else {
            return error.InvalidArgument;
        }
    }

    fn write(self: *const Self, writer: Writer) !void {
        switch (self.kind) {
            .Identifier => {
                try writer.print("{s}", .{self.lexeme()});
            },
            .Abstraction => |abstraction| {
                try writer.print("\\{s}. {wr}", .{ abstraction.of.lexeme(), abstraction.over });
            },
            .Application => |application| {
                _ = try writer.print("{wr} {wr}", .{ application.of, application.to });
            },
        }
    }

    fn serialize(self: *const Self, writer: Writer) !void {
        switch (self.kind) {
            .Identifier => {
                _ = try writer.print("{s}", .{self.lexeme()});
            },
            .Abstraction => |abstraction| {
                try writer.print("Abs({s}, {srl})", .{ abstraction.of.lexeme(), abstraction.over });
            },
            .Application => |application| {
                try writer.print("App({srl}, {srl})", .{ application.of, application.to });
            },
        }
    }
};
