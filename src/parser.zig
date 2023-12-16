const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;
const StringHashSet = std.StringHashMap(void);

const main = @import("main.zig");
const LOGGING = main.LOGGING;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Application > Abstraction
pub const Token = struct {
    const Kind = union(enum) {
        Identifier: []const u8,
        BackSlash,

        Dot,
        Equals,
        Newline,
        EOF,

        Space,
        LBrace,
        RBrace,
    };

    const Self = @This();

    kind: Kind,

    fn new(kind: Kind) Self {
        return .{
            .kind = kind,
        };
    }
};

const Identifier = []const u8;

const ParseError = error{ UnexpectedToken, ReachedStartOfHistory, CannotAdvancePastEOF, AmbiguousAbstraction } || Allocator.Error;

const Abstraction = struct {
    of: Identifier,
    over: *Expression,
};

const Application = struct {
    of: *Expression,
    to: *Expression,
};

pub const Expression = union(enum) {
    Identifier: Identifier,
    Abstraction: Abstraction,
    Application: Application,

    const Self = @This();

    pub fn init(allocator: Allocator) !*Self {
        return try allocator.create(Self);
    }

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

    pub fn deep_copy(self: *Self, allocator: Allocator) !*Self {
        switch (self.*) {
            .Identifier => {
                const ident = try allocator.create(Self);
                ident.* = self.*;
                return ident;
            },
            .Abstraction => |abs| {
                const new_abs = try allocator.create(Self);
                new_abs.* = .{ .Abstraction = .{
                    .of = abs.of,
                    .over = try abs.over.deep_copy(allocator),
                } };
                return new_abs;
            },
            .Application => |app| {
                const new_app = try allocator.create(Self);
                new_app.* = .{ .Application = .{
                    .of = try app.of.deep_copy(allocator),
                    .to = try app.to.deep_copy(allocator),
                } };
                return new_app;
            },
        }
    }

    fn replace(self: *Self, target: []const u8, with: *Expression, allocator: Allocator) !*Expression {
        switch (self.*) {
            .Identifier => |ident| {
                if (std.mem.eql(u8, ident, target)) {
                    return try with.deep_copy(allocator);
                } else {
                    return try self.deep_copy(allocator);
                }
            },
            .Abstraction => |abs| {
                const replaced = try abs.over.replace(target, with, allocator);
                const result = try allocator.create(Self);
                result.* = .{ .Abstraction = .{
                    .of = abs.of,
                    .over = replaced,
                } };
                return result;
            },
            .Application => |app| {
                const of_replaced = try app.of.replace(target, with, allocator);
                const to_replaced = try app.to.replace(target, with, allocator);
                const result = try allocator.create(Self);
                result.* = .{ .Application = .{
                    .of = of_replaced,
                    .to = to_replaced,
                } };
                return result;
            },
        }
    }

    pub fn beta_reduce(self: *Self, allocator: Allocator) !*Expression {
        switch (self.*) {
            .Application => |app| {
                switch (app.of.*) {
                    .Abstraction => |abs| {
                        return try abs.over.replace(abs.of, app.to, allocator);
                    },
                    else => {
                        const reduced = try allocator.create(Self);
                        reduced.* = .{ .Application = .{
                            .of = try app.of.beta_reduce(allocator),
                            .to = try app.to.beta_reduce(allocator),
                        } };
                        return reduced;
                    },
                }
            },
            else => {
                return try self.deep_copy(allocator);
            },
        }
    }

    pub fn write(self: *const Self, writer: Writer) !void {
        try self.write_aux(&writer);
        _ = try writer.write("\n");
    }
    pub fn serialize(self: *const Self, writer: Writer) !void {
        try self.serialize_aux(&writer);
        _ = try writer.write("\n");
    }

    fn write_aux(self: *const Self, writer: *const Writer) !void {
        switch (self.*) {
            .Identifier => |lexeme| {
                _ = try writer.print("({s})", .{lexeme});
            },
            .Abstraction => |abstraction| {
                _ = try writer.write("(\\");
                _ = try writer.print("{s}", .{abstraction.of});
                _ = try writer.write(". ");
                _ = try abstraction.over.write_aux(writer);
                _ = try writer.write(")");
            },
            .Application => |application| {
                _ = try writer.write("(");
                _ = try application.of.write_aux(writer);
                _ = try writer.write(" ");
                _ = try application.to.write_aux(writer);
                _ = try writer.write(")");
            },
        }
    }

    fn serialize_aux(self: *const Self, writer: *const Writer) !void {
        switch (self.*) {
            .Identifier => |lexeme| {
                _ = try writer.print("{s}", .{lexeme});
            },
            .Abstraction => |abstraction| {
                _ = try writer.print("Abs({s}, ", .{abstraction.of});
                _ = try abstraction.over.serialize_aux(writer);
                _ = try writer.write(")");
            },
            .Application => |application| {
                _ = try writer.write("App(");
                _ = try application.of.serialize_aux(writer);
                _ = try writer.write(", ");
                _ = try application.to.serialize_aux(writer);
                _ = try writer.write(")");
            },
        }
    }
};

const special_chars = "\\.=() \n\r";
fn is_special_char(char: u8) bool {
    for (special_chars) |special_char| {
        if (char == special_char) {
            return true;
        }
    }
    return false;
}

pub const Parser = struct {
    const Self = @This();
    const Tokens = std.ArrayList(Token);

    source: []const u8,
    token_index: u32,
    tokens: Tokens,
    ast: ?*Expression,
    allocator: Allocator,

    pub fn init(source: []const u8, tokens_list: Tokens, ast_allocator: Allocator) !Self {
        return .{
            .source = source,
            .token_index = 0,
            .tokens = tokens_list,
            .ast = null,
            .allocator = ast_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    fn eof(self: *Self) bool {
        return self.source.len == 0;
    }

    fn advance_source(self: *Self) !void {
        if (self.eof()) {
            return error.CannotAdvancePastEOF;
        }
        if (!self.eof()) {
            self.source.ptr += 1;
            self.source.len -= 1;
        }
    }

    fn ignore_space(self: *Self) !bool {
        var ignored = false;
        while (true) {
            const _peek = try self.peek();
            if (_peek.kind == .Space) {
                self.token_index += 1;
                ignored = true;
            } else {
                break;
            }
        }
        return ignored;
    }

    fn ignore_newlines(self: *Self) !bool {
        var ignored = false;
        while (true) {
            const _peek = try self.peek();
            if (_peek.kind == .Newline) {
                self.token_index += 1;
                ignored = true;
            } else {
                break;
            }
        }
        return ignored;
    }

    fn expr_aux(self: *Self, abstracted_ids: *StringHashSet) ParseError!?*Expression {
        while (try self.ignore_space() or try self.ignore_newlines()) {}
        var _expr = if (try self.atom(abstracted_ids)) |_atom| _atom else {
            std.log.info("expr: null", .{});
            return null;
        };

        while ((try self.peek()).kind == .Space) {
            self.token_index += 1;
            if (try self.atom(abstracted_ids)) |unwrapped_atom| {
                const new_expr = try self.allocator.create(Expression);
                new_expr.* = .{
                    .Application = .{
                        .of = _expr,
                        .to = unwrapped_atom,
                    },
                };
                _expr = new_expr;
            } else {
                const _peek1 = try self.peek();
                if (_peek1.kind == .Newline or _peek1.kind == .EOF) {
                    std.log.info("expr: newline | eof", .{});
                    self.token_index += 1;
                    break;
                } else {
                    std.log.err("Unexpedted Token {any}.", .{(try self.next()).kind});
                    return error.UnexpectedToken;
                }
            }
        }
        return _expr;
    }

    pub fn expr(self: *Self) ParseError!?*Expression {
        var abstracted_ids = StringHashSet.init(gpa.allocator());
        defer abstracted_ids.deinit();

        return expr_aux(self, &abstracted_ids);
    }

    fn atom(self: *Self, abstracted_ids: *StringHashSet) ParseError!?*Expression {
        const _peek = try self.peek();
        switch (_peek.kind) {
            .Identifier => |lexeme| {
                std.log.info("atom: {s}", .{lexeme});
                self.token_index += 1;
                const _ident = try self.allocator.create(Expression);
                _ident.* = .{ .Identifier = lexeme };
                return _ident;
            },
            .LBrace => {
                std.log.info("atom: '('", .{});
                self.token_index += 1;
                const _expr = if (try self.expr_aux(abstracted_ids)) |_expr| _expr else {
                    std.log.err("Expected an expression but got {any}", .{(try self.peek()).kind});
                    return error.UnexpectedToken;
                };
                const _peek1 = try self.next();
                if (_peek1.kind == .RBrace) {
                    std.log.info("atom: ')'", .{});
                    return _expr;
                } else {
                    std.log.err("Expected ')' but got {any}", .{_peek1.kind});
                    return error.UnexpectedToken;
                }
            },
            .BackSlash => {
                std.log.info("atom: '\\'", .{});
                self.token_index += 1;
                const _peek1 = try self.next();
                const _lexeme = switch (_peek1.kind) {
                    .Identifier => |lexeme| lexeme,
                    else => {
                        std.log.err("Expected identifier but got {any}", .{_peek1.kind});
                        return error.UnexpectedToken;
                    },
                };
                std.log.info("atom: {s}", .{_lexeme});
                const _peek2 = try self.next();
                if (_peek2.kind != .Dot) {
                    std.log.err("Expected '.' but got {any}", .{_peek2.kind});
                    return error.UnexpectedToken;
                }
                std.log.info("atom: '.'", .{});

                if (abstracted_ids.contains(_lexeme)) {
                    std.log.err("An identifier with the name '{s}' has already been abstracted from the current expression.", .{_lexeme});
                    std.log.info("Please change the name of the variable to something that is not already used in the expression.", .{});
                    return ParseError.AmbiguousAbstraction;
                } else {
                    try abstracted_ids.putNoClobber(_lexeme, {});
                }

                const _expr = if (try self.expr_aux(abstracted_ids)) |_expr| _expr else {
                    std.log.err("Expected an expression but got {any}", .{(try self.peek()).kind});
                    return error.UnexpectedToken;
                };

                const _abstraction = try self.allocator.create(Expression);
                _abstraction.* = .{
                    .Abstraction = .{
                        .of = _lexeme,
                        .over = _expr,
                    },
                };
                return _abstraction;
            },
            else => {
                return null;
            },
        }
    }

    fn push_to_history(self: *Self, token: Token) !void {
        try self.tokens.append(token);
    }

    pub fn peek(self: *Self) !Token {
        while (self.token_index >= self.tokens.items.len) {
            try self.tokenize();
        }
        const token = self.tokens.items[self.token_index];
        std.log.info("peek: {any}", .{token.kind});
        return token;
    }

    pub fn next(self: *Self) !Token {
        while (self.token_index >= self.tokens.items.len) {
            try self.tokenize();
        }
        const token = self.tokens.items[self.token_index];
        std.log.info("next: {any}", .{token.kind});
        self.token_index += 1;
        return token;
    }

    pub fn rewind(self: *Self) !void {
        if (self.token_index == 0) {
            return error.ReachedStartOfHistory;
        }
        self.token_index -= 1;
    }

    fn tokenize(self: *Self) !void {
        if (self.eof()) {
            try self.push_to_history(Token.new(.EOF));
            return;
        }

        while (self.source[0] == '\r') {
            try self.advance_source();
            if (self.eof()) {
                try self.push_to_history(Token.new(.EOF));
                return;
            }
        }

        switch (self.source[0]) {
            '\\' => {
                try self.advance_source();
                try self.push_to_history(Token.new(.BackSlash));
            },
            '.' => {
                try self.advance_source();
                try self.push_to_history(Token.new(.Dot));
            },
            '=' => {
                try self.advance_source();
                try self.push_to_history(Token.new(.Equals));
            },
            '(' => {
                try self.advance_source();
                try self.push_to_history(Token.new(.LBrace));
            },
            ')' => {
                try self.advance_source();
                try self.push_to_history(Token.new(.RBrace));
            },
            '\n' => {
                try self.advance_source();
                try self.push_to_history(Token.new(.Newline));
            },
            '\t', ' ' => {
                while (!self.eof() and (self.source[0] == ' ' or self.source[0] == '\t')) {
                    try self.advance_source();
                }
                try self.push_to_history(Token.new(.Space));
            },
            else => {
                var lexeme: []const u8 = self.source[0..0];
                while (!self.eof() and !is_special_char(self.source[0])) {
                    try self.advance_source();
                    lexeme.len += 1;
                }
                if (lexeme.len == 0) {
                    return error.UnexpectedToken;
                }
                try self.push_to_history(Token.new(.{ .Identifier = lexeme }));
            },
        }

        std.log.info("tokenized: {any}", .{self.tokens.getLast()});
    }
};
