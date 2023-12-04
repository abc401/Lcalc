const std = @import("std");
// Application > Abstraction
const Token = struct {
    const Kind = union(enum) {
        Identifier: []const u8,
        BackSlash,
        Dot,
        Equals,
        LBrace,
        RBrace,
        Space,
        Newline,
        EOF,
    };

    const Self = @This();

    kind: Kind,

    fn new(kind: Kind) Self {
        return .{
            .kind = kind,
        };
    }
};

const Identifier = struct {
    lexeme: []u8,
};

const Expression = union(enum) {
    Identifier: []u8,
    Abstraction: struct {
        abstracted: []u8,
        over: *Expression,
    },
    Application: struct {
        of: *Expression,
        to: *Expression,
    },
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
    const History = std.ArrayList(Token);

    source: []const u8,
    token_index: u32,
    history: History,
    allocator: std.mem.Allocator,
    is_done: bool,

    pub fn init(source: []const u8, allocator: std.mem.Allocator) !Self {
        return .{
            .source = source,
            .allocator = allocator,
            .history = try History.initCapacity(allocator, 10),
            .is_done = false,
            .token_index = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit();
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

    fn parse_expression(self: *Self) !void {
        const _next = self.next();
        switch (_next.kind) {
            .Identifier => |lexeme| {
                _ = lexeme;
            },
        }
    }

    fn push_to_history(self: *Self, token: Token) !void {
        try self.history.append(token);
    }

    pub fn next(self: *Self) !Token {
        if (self.token_index <= self.history.items.len) {
            try self.tokenize();
        }
        const token = self.history.items[self.token_index];
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
