const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashSet = std.StringHashMap(void);
const File = std.fs.File;
const Expression = @import("expr.zig").Expression;

const main = @import("main.zig");
const LOGGING = main.LOGGING;
var gpa = main.GeneralPurposeAllocator{};

pub const Location = struct {
    source: []const u8,
    start: usize = 0,
    end: usize = 0,

    const Self = @This();

    // TODO: Change all the places where Location.NULL is used to use
    // an actual nullable i.e. '?Location'

    // The following is a sentinal value that represents null for this struct.
    pub const NULL = Self.new(source: {
        var slice: []const u8 = undefined;
        slice.ptr = @ptrFromInt(@as(usize, 1));
        slice.len = 0;
        break :source slice;
    }, 0, 0);

    pub fn new(source: []const u8, start: usize, end: usize) Self {
        return .{
            .source = source,
            .start = start,
            .end = end,
        };
    }

    pub fn lexeme(self: *const Self) []const u8 {
        return self.source[self.start..self.end];
    }
};

pub const Token = struct {
    const Kind = union(enum) {
        Identifier,
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

    loc: Location,

    fn new(kind: Kind, source: []const u8, start: usize, len: usize) Self {
        return .{
            .kind = kind,
            .loc = .{
                .source = source,
                .start = start,
                .end = start + len,
            },
        };
    }

    fn newParser(kind: Kind, parser: *const Parser, len: usize) Self {
        return .{
            .kind = kind,
            .loc = .{
                .source = parser.source,
                .start = parser.char_index,
                .end = parser.char_index + len,
            },
        };
    }

    fn lexeme(self: *const Self) []const u8 {
        return self.loc.lexeme();
    }
};

const ParseError = error{
    UnexpectedToken,
    ReachedStartOfHistory,
    CannotAdvancePastEOF,
    AmbiguousAbstraction,
} || Allocator.Error;

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
    char_index: usize,
    token_index: usize,
    tokens: Tokens,
    ast: ?*Expression,
    allocator: Allocator,

    pub fn init(source: []const u8, tokens_list: Tokens, ast_allocator: Allocator) !Self {
        return .{
            .source = source,
            .char_index = 0,
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
        return self.char_index >= self.source.len;
    }

    fn advance_source(self: *Self) !void {
        if (self.eof()) {
            return error.CannotAdvancePastEOF;
        }
        if (!self.eof()) {
            self.char_index += 1;
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
            if (try self.atom(abstracted_ids)) |_atom| {
                const new_expr = try self.allocator.create(Expression);
                new_expr.* = .{
                    .kind = .{
                        .Application = .{
                            .of = _expr,
                            .to = _atom,
                        },
                    },
                    .loc = Location.new(
                        self.source,
                        _expr.loc.start,
                        _atom.loc.end,
                    ),
                };
                _expr = new_expr;
            } else {
                const newline_of_eof = try self.peek();
                if (newline_of_eof.kind == .Newline or newline_of_eof.kind == .EOF) {
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
            .Identifier => {
                std.log.info("atom: {s}", .{_peek.lexeme()});
                self.token_index += 1;
                const _ident = try self.allocator.create(Expression);
                _ident.* = .{
                    .kind = .Identifier,
                    .loc = _peek.loc,
                };
                return _ident;
            },
            .LBrace => {
                std.log.info("atom: '('", .{});
                self.token_index += 1;
                const _expr = if (try self.expr_aux(abstracted_ids)) |_expr| _expr else {
                    std.log.err("Expected an expression but got {any}", .{(try self.peek()).kind});
                    return error.UnexpectedToken;
                };
                const rbrace = try self.next();
                if (rbrace.kind == .RBrace) {
                    std.log.info("atom: ')'", .{});
                    // if (_expr.kind != .Identifier) {
                    //     _expr.loc.start = _peek.loc.start;
                    //     _expr.loc.end = rbrace.loc.end;
                    // }
                    return _expr;
                } else {
                    std.log.err("Expected ')' but got {any}", .{rbrace.kind});
                    return error.UnexpectedToken;
                }
            },
            .BackSlash => {
                std.log.info("atom: '\\'", .{});
                self.token_index += 1;
                const ident = try self.next();
                if (ident.kind != .Identifier) {
                    std.log.err("Expected identifier but got {any}", .{ident.kind});
                    return error.UnexpectedToken;
                }
                std.log.info("atom: {s}", .{ident.lexeme()});
                const dot = try self.next();
                if (dot.kind != .Dot) {
                    std.log.err("Expected '.' but got {any}", .{dot.kind});
                    return error.UnexpectedToken;
                }
                std.log.info("atom: '.'", .{});

                if (abstracted_ids.contains(ident.lexeme())) {
                    std.log.err("The identifier '{s}' has already been abstracted from the current expression.", .{ident.lexeme()});
                    std.log.info("Please change the name of the variable to something that is not already used in the expression.", .{});
                    return ParseError.AmbiguousAbstraction;
                }
                try abstracted_ids.putNoClobber(ident.lexeme(), {});

                const _expr = if (try self.expr_aux(abstracted_ids)) |_expr| _expr else {
                    std.log.err("Expected an expression but got {any}", .{(try self.peek()).kind});
                    return error.UnexpectedToken;
                };

                const abs = try self.allocator.create(Expression);
                abs.* = .{
                    .kind = .{
                        .Abstraction = .{
                            .of = ident.loc,
                            .over = _expr,
                        },
                    },
                    .loc = Location.new(
                        self.source,
                        _peek.loc.start,
                        _expr.loc.end,
                    ),
                };
                return abs;
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
            std.log.info("Needed to tokenize.", .{});
            try self.tokenize();
        }
        const token = self.tokens.items[self.token_index];
        std.log.info("peek: {any}", .{token.kind});
        return token;
    }

    pub fn next(self: *Self) !Token {
        while (self.token_index >= self.tokens.items.len) {
            std.log.info("Needed to tokenize.", .{});
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
            try self.push_to_history(Token.newParser(.EOF, self, 0));
            return;
        }

        while (self.source[self.char_index] == '\r') {
            try self.advance_source();
            if (self.eof()) {
                try self.push_to_history(Token.newParser(.EOF, self, 0));
                return;
            }
        }

        switch (self.source[self.char_index]) {
            '\\' => {
                try self.advance_source();
                try self.push_to_history(Token.newParser(.BackSlash, self, 1));
            },
            '.' => {
                try self.advance_source();
                try self.push_to_history(Token.newParser(.Dot, self, 1));
            },
            '=' => {
                try self.advance_source();
                try self.push_to_history(Token.newParser(.Equals, self, 1));
            },
            '(' => {
                try self.advance_source();
                try self.push_to_history(Token.newParser(.LBrace, self, 1));
            },
            ')' => {
                try self.advance_source();
                try self.push_to_history(Token.newParser(.RBrace, self, 1));
            },
            '\n' => {
                try self.advance_source();
                try self.push_to_history(Token.newParser(.Newline, self, 1));
            },
            '\t', ' ' => {
                var len: usize = 0;
                const start = self.char_index;
                while (!self.eof() and (self.source[self.char_index] == ' ' or self.source[self.char_index] == '\t')) {
                    len += 1;
                    try self.advance_source();
                }
                try self.push_to_history(Token.new(.Space, self.source, start, len));
            },
            else => {
                const start = self.char_index;
                var len: usize = 0;
                while (!self.eof() and !is_special_char(self.source[self.char_index])) {
                    try self.advance_source();
                    len += 1;
                }
                if (len == 0) {
                    return error.UnexpectedToken;
                }
                try self.push_to_history(Token.new(.Identifier, self.source, start, len));
            },
        }

        std.log.info("tokenized: {any}", .{self.tokens.getLast()});
    }
};
