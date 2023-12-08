const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

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
        switch (self.*) {
            .Identifier => |lexeme| {
                _ = try writer.print("{s}", .{lexeme});
            },
            .Abstraction => |abstraction| {
                _ = try writer.write("\\");
                _ = try writer.print("{s}", abstraction.of);
                _ = try writer.write(".");
                _ = try abstraction.over.write(writer);
            },
            .Application => |application| {
                _ = try application.of.write(writer);
                _ = try writer.write(" ");
                _ = try application.to.write(writer);
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

fn is_control_char(char: u8) bool {
    return char < 0x20 or char == 0x7f;
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

    fn ignore_space(self: *Self) !void {
        const _peek = try self.peek();
        if (_peek.kind == .Space) {
            self.token_index += 1;
        }
        return;
    }

    pub fn expr(self: *Self) ParseError!?*Expression {
        try self.ignore_space();
        var _expr = if (try self.atom()) |_atom| _atom else {
            return null;
        };
        const _peek = try self.peek();
        while (_peek.kind == .Space) {
            self.token_index += 1;
            const _atom = try self.atom();
            if (_atom) |unwrapped_atom| {
                const new_expr = try self.allocator.create(Expression);
                new_expr.* = .{
                    .Application = .{
                        .of = _expr,
                        .to = unwrapped_atom,
                    },
                };
                _expr = new_expr;
            } else if ((try self.next()).kind == .Newline or (try self.next()).kind == .EOF) {
                self.token_index += 1;
                break;
            } else {
                std.log.err("Unexpedted Token {any}.", .{(try self.next()).kind});
                return error.UnexpectedToken;
            }
        }
        return _expr;
    }

    fn atom(self: *Self) ParseError!?*Expression {
        const _peek = try self.peek();
        switch (_peek.kind) {
            .Identifier => |lexeme| {
                self.token_index += 1;
                const _ident = try self.allocator.create(Expression);
                _ident.* = .{ .Identifier = lexeme };
                return _ident;
            },
            .LBrace => {
                const _expr = if (try self.expr()) |_expr| _expr else {
                    std.log.err("Expected an expression but got {any}", .{(try self.peek()).kind});
                    return error.UnexpectedToken;
                };
                const _peek1 = try self.peek();
                if (_peek1.kind == .RBrace) {
                    return _expr;
                } else {
                    std.log.err("Expected ')' but got {any}", .{_peek1.kind});
                    return error.UnexpectedToken;
                }
            },
            .BackSlash => {
                self.token_index += 1;
                const _peek1 = try self.next();
                const _lexeme = switch (_peek.kind) {
                    .Identifier => |lexeme| lexeme,
                    else => {
                        std.log.err("Expected identifier but got {any}", .{_peek1.kind});
                        return error.UnexpectedToken;
                    },
                };
                const _peek2 = try self.next();
                if (_peek2.kind != .Dot) {
                    std.log.err("Expected '.' but got {any}", .{_peek2.kind});
                    return error.UnexpectedToken;
                }
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

    fn dot(self: *Self) !?void {
        const _peek = try self.peek();
        switch (_peek.kind) {
            .Dot => {
                self.token_index += 1;
                return;
            },
            else => {
                return null;
            },
        }
    }

    fn ident(self: *Self) !?Identifier {
        const _peek = try self.peek();
        switch (_peek.kind) {
            .Identifier => |lexeme| {
                self.token_index += 1;
                return lexeme;
            },
            else => return null,
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
        return token;
    }

    pub fn next(self: *Self) !Token {
        while (self.token_index >= self.tokens.items.len) {
            try self.tokenize();
        }
        const token = self.tokens.items[self.token_index];
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
    }
};
