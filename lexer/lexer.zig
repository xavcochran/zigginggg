const std = @import("std");

const Token = union(enum) {
    TkTrue,
    TkFalse,
    TkAnd,
    TkOr,
    TkLParen,
    TkRParen,
    TkId: []const u8,
    TkEnd,
};

pub fn charIsWhiteSpace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

fn is_id_char(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '\'';
}

const State = struct {
    index: usize,
    input: []const u8,
    input_len: usize,

    fn init(input: []const u8) State {
        return State{ .index = 0, .input = input, .input_len = input.len };
    }

    fn is_more(self: *State) bool {
        return self.index < self.input_len;
    }

    fn peak(self: *State) u8 {
        return self.input[self.index];
    }

    fn eat(self: *State, c: u8) void {
        if (self.peak() == c) {
            self.index += 1;
        } else {
            std.debug.print("Expected {}\n", .{c});
            std.process.exit(1);
        }
    }

    fn lex_kw_or_id(self: *State) Token {
        var lexeme = std.ArrayList(u8).init(std.heap.page_allocator);

        while (self.is_more() and is_id_char(self.peak())) {
            const c = self.peak();
            self.eat(c);
            lexeme.append(c) catch {
                std.debug.print("Failed to append character to lexeme\n", .{});
                std.process.exit(1);
            };
        }

        const lexeme_slice = lexeme.toOwnedSlice() catch {
            std.debug.print("Failed to convert lexeme to slice\n", .{});
            std.process.exit(1);
        };


        var token: Token = undefined;
        if (std.mem.eql(u8, lexeme_slice, "true")) {
            token = Token.TkTrue;
        } else if (std.mem.eql(u8, lexeme_slice, "false")) {
            token = Token.TkFalse;
        } else if (std.mem.eql(u8, lexeme_slice, "and")) {
            token = Token.TkAnd;
        } else if (std.mem.eql(u8, lexeme_slice, "or")) {
            token = Token.TkOr;
        } else {
             token = Token{ .TkId = lexeme_slice };
        }

        return token;
    }
};

pub fn main() void {
    const s = "foo && true || (false && bar)";

    var state = State.init(s);
    var tokens = std.ArrayList(Token).init(std.heap.page_allocator);

    while (state.is_more()) {
        const c = state.peak();
        switch (c) {
            '(' => {
                state.eat('(');
                tokens.append(Token.TkLParen) catch {
                    std.debug.print("Failed to append token\n", .{});
                    std.process.exit(1);
                };
            },
            ')' => {
                state.eat(')');
                tokens.append(Token.TkRParen) catch {
                    std.debug.print("Failed to append token\n", .{});
                    std.process.exit(1);
                };
            },
            '&' => {
                state.eat('&');
                state.eat('&');
                tokens.append(Token.TkAnd) catch {
                    std.debug.print("Failed to append token\n", .{});
                    std.process.exit(1);
                };
            },
            '|' => {
                state.eat('|');
                state.eat('|');
                tokens.append(Token.TkOr) catch {
                    std.debug.print("Failed to append token\n", .{});
                    std.process.exit(1);
                };
            },
            else => {
                if (is_id_char(c)) {
                    const token = state.lex_kw_or_id();
                    tokens.append(token) catch {
                        std.debug.print("Failed to append token\n", .{});
                        std.process.exit(1);
                    };
                } else if (charIsWhiteSpace(c)) {
                    state.eat(c);
                } else {
                    std.debug.print("Unexpected character: {}\n", .{c});
                    state.eat(c);
                }
            },
        }
    }

     tokens.append(Token.TkEnd) catch {
        std.debug.print("Failed to append token\n", .{});
        std.process.exit(1);
    };

    for (tokens.items) |token| {
        switch (token) {
            Token.TkTrue => std.debug.print("TOKEN: true\n", .{}),
            Token.TkFalse => std.debug.print("TOKEN: false\n", .{}),
            Token.TkAnd => std.debug.print("TOKEN: &&\n", .{}),
            Token.TkOr => std.debug.print("TOKEN: ||\n", .{}),
            Token.TkLParen => std.debug.print("TOKEN: (\n", .{}),
            Token.TkRParen => std.debug.print("TOKEN: )\n", .{}),
            Token.TkId => |id| std.debug.print("TOKEN: Id: {s}\n", .{id}),
            Token.TkEnd => std.debug.print("TOKEN: End\n", .{}),
        }
    }
}
