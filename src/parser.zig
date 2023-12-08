const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

const LOGGING = @import("main.zig").LOGGING;

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

const ParseError = error{
    UnexpectedToken,
    ReachedStartOfHistory,
    CannotAdvancePastEOF,
} || Allocator.Error;

const Abstraction = struct {
    of: Identifier,
    over: *Expression,
};

const Application = struct {
    of: *Expression,
    to: *Expression,
};

const Expression = union(enum) {
    Identifier: Identifier,
    Abstraction: Abstraction,
    Application: Application,

    const Self = @This();

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
                _ = try writer.print("{s}", .{lexeme});
            },
            .Abstraction => |abstraction| {
                _ = try writer.write("\\");
                _ = try writer.print("{s}", .{abstraction.of});
                _ = try writer.write(". ");
                _ = try abstraction.over.write_aux(writer);
            },
            .Application => |application| {
                _ = try application.of.write_aux(writer);
                _ = try writer.write(" ");
                _ = try application.to.write_aux(writer);
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

    pub fn expr(self: *Self) ParseError!?*Expression {
        while (try self.ignore_space() or try self.ignore_newlines()) {}
        var _expr = if (try self.atom()) |_atom| _atom else {
            std.log.info("expr: null", .{});
            return null;
        };
        while ((try self.peek()).kind == .Space) {
            self.token_index += 1;
            if (try self.atom()) |unwrapped_atom| {
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

    fn atom(self: *Self) ParseError!?*Expression {
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
                const _expr = if (try self.expr()) |_expr| _expr else {
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
                const _expr = if (try self.expr()) |_expr| _expr else {
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
