const std = @import("std");

const DataType = enum(u6) {
    Integer = 1,
    Float = 2,
    String = 3,
    _, // for more types
};

const TaggedData = union(DataType) {
    Integer: i32,
    Float: f32,
    String: []const u8,
};

// truncate 64 bits pointer to 48 bits
fn truncatePointer(ptr: usize) u48 {
    return @truncate(ptr);
}
// extend 48 bits for pointer to 64 bits
fn extendPointer(val: u48) usize {
    const bit47 = (val >> 47) & 1;
    const upper_bits: u17 = if (bit47 == 1) 0x1FFFF else 0;
    return (@as(usize, upper_bits) << 48) | val;
}

const CustomPointer = packed struct {
    type_id: DataType,
    some_metadata: u10,
    data: u48,

    // create tagged pointer from value from header
    pub fn from(allocator: std.mem.Allocator, value: TaggedData) !CustomPointer {
        switch (value) {
            .Integer => |int_val| {
                const stored = try allocator.create(i32);
                stored.* = int_val;
                return CustomPointer{
                    .type_id = .Integer,
                    .some_metadata = 0,
                    .data = truncatePointer(@intFromPtr(stored)),
                };
            },
            .Float => |float_val| {
                const stored = try allocator.create(f32);
                stored.* = float_val;
                return CustomPointer{
                    .type_id = .Float,
                    .some_metadata = 0,
                    .data = truncatePointer(@intFromPtr(stored)),
                };
            },
            .String => |str| {
                if (str.len > 255) return error.StringTooLong;
                // Allocate and copy the string
                const stored_str = try allocator.dupe(u8, str);
                return CustomPointer{
                    .type_id = .String,
                    .some_metadata = @intCast(str.len),
                    .data = truncatePointer(@intFromPtr(stored_str.ptr)),
                };
            },
        }
    }

    // get value
    pub fn getValue(self: CustomPointer) TaggedData {
        const full_ptr = extendPointer(self.data);
        return switch (self.type_id) {
            .Integer => TaggedData{ .Integer = @as(*i32, @ptrFromInt(full_ptr)).* },
            .Float => TaggedData{ .Float = @as(*f32, @ptrFromInt(full_ptr)).* },
            .String => blk: {
                const ptr = @as([*]const u8, @ptrFromInt(full_ptr));
                const len: usize = self.some_metadata;
                break :blk TaggedData{ .String = ptr[0..len] };
            },
            _ => unreachable,
        };
    }
    //Free stuff
    pub fn deinit(self: CustomPointer, allocator: std.mem.Allocator) void {
        const full_ptr = extendPointer(self.data);
        switch (self.type_id) {
            .Integer => {
                const ptr = @as(*i32, @ptrFromInt(full_ptr));
                allocator.destroy(ptr);
            },
            .Float => {
                const ptr = @as(*f32, @ptrFromInt(full_ptr));
                allocator.destroy(ptr);
            },
            .String => {
                const ptr = @as([*]const u8, @ptrFromInt(full_ptr));
                const len: usize = self.some_metadata;
                allocator.free(ptr[0..len]);
            },
            _ => unreachable,
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const int_value: TaggedData = .{ .Integer = 58992 };
    const float_value: TaggedData = .{ .Float = 1.999 };
    const string_value: TaggedData = .{ .String = "Yooo" };

    const int_ptr = try CustomPointer.from(allocator, int_value);
    const float_ptr = try CustomPointer.from(allocator, float_value);
    const string_ptr = try CustomPointer.from(allocator, string_value);

    const retrieved_int = int_ptr.getValue();
    const retrieved_float = float_ptr.getValue();
    const retrieved_string = string_ptr.getValue();

    std.debug.print("Integer: {}\n", .{retrieved_int.Integer});
    std.debug.print("Float: {d}\n", .{retrieved_float.Float});
    std.debug.print("String: {s}\n", .{retrieved_string.String});

    std.debug.print("\nActual field sizes:\n", .{});
    std.debug.print("type_id field: {} bits ({} bytes)\n", .{ @bitSizeOf(@TypeOf(int_ptr.type_id)), @sizeOf(@TypeOf(int_ptr.type_id)) });
    std.debug.print("some_metadata field: {} bits ({} bytes)\n", .{ @bitSizeOf(@TypeOf(int_ptr.some_metadata)), @sizeOf(@TypeOf(int_ptr.some_metadata)) });
    std.debug.print("data pointer field: {} bits ({} bytes)\n", .{ @bitSizeOf(@TypeOf(int_ptr.data)), @sizeOf(@TypeOf(int_ptr.data)) });
    
    int_ptr.deinit(allocator);
    float_ptr.deinit(allocator);
    string_ptr.deinit(allocator);
}
