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

    source: []const u8,

    pub fn init(source: []const u8) Self {
        return .{
            .source = source,
        };
    }

    fn eof(self: *Self) bool {
        return self.source.len == 0;
    }

    fn advance_source(self: *Self) void {
        if (!self.eof()) {
            self.source.ptr += 1;
            self.source.len -= 1;
        }
    }

    fn parse_expression(self: *Self) !void {
        const next = self.next_token();
        switch (next.kind) {
            .Identifier => |lexeme| {
                _ = lexeme;
            },
        }
    }

    pub fn next_token(self: *Self) !Token {
        if (self.eof()) {
            return Token.new(.EOF);
        }

        while (self.source[0] == '\r') {
            self.advance_source();
            if (self.eof()) {
                return Token.new(.EOF);
            }
        }

        switch (self.source[0]) {
            '\\' => {
                self.advance_source();
                return Token.new(.BackSlash);
            },
            '.' => {
                self.advance_source();
                return Token.new(.Dot);
            },
            '=' => {
                self.advance_source();
                return Token.new(.Equals);
            },
            '(' => {
                self.advance_source();
                return Token.new(.LBrace);
            },
            ')' => {
                self.advance_source();
                return Token.new(.RBrace);
            },
            '\n' => {
                self.advance_source();
                return Token.new(.Newline);
            },
            '\t', ' ' => {
                while (!self.eof() and (self.source[0] == ' ' or self.source[0] == '\t')) {
                    self.advance_source();
                }
                return Token.new(.Space);
            },
            else => {
                var lexeme: []const u8 = self.source[0..0];
                while (!self.eof() and !is_special_char(self.source[0])) {
                    self.advance_source();
                    lexeme.len += 1;
                }
                if (lexeme.len == 0) {
                    return error.UnexpectedToken;
                }
                return Token.new(.{ .Identifier = lexeme });
            },
        }
    }
};
