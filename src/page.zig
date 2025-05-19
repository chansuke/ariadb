const std = @import("std");

pub const Page = struct {
    // slice to represent the buffer.
    bb: []u8,

    const CHARSET = std.encoding.utf8;

    // Create data buffers.
    pub fn initWithSize(allocator: std.mem.Allocator, size: usize) !Page {
        const buffer = try allocator.alloc(u8, size);
        return Page{ .bb = buffer };
    }

    // Create log pages.
    pub fn initWithBytes(buffer: []const u8) !Page {
        return Page{ .bb = buffer };
    }

    pub fn getInt(self: *Page, offset: usize) !i64 {
        if (offset + @sizeOf(i64) > self.bb.len) {
            return error.OutOfBounds;
        }

        return self.bb[offset];
    }

    pub fn setInt(self: *Page, offset: usize, n: i64) !i64 {
        self.bb[offset] = n;
    }

    pub fn getBytes(self: *Page, offset: usize) ![]u8 {
        if (offset + @sizeOf(i32) > self.bb.len) {
            return error.OutOfBounds;
        }

        const length = std.mem.readInt(i32, self.bb[offset .. offset + @sizeOf(i32)], .little);
        // @as(i32, @intCast(i));
        const byteLength = @as(usize, @intCast(length));

        const start = offset + @sizeOf(i32);
        if (start + byteLength > self.bb.len) {
            return error.OutOfBounds;
        }

        return self.bb[start .. start + byteLength];
    }

    pub fn setBytes(self: *Page, offset: usize, buffer: []const u8) !void {
        const lengthSize = @sizeOf(i32);
        if (offset + lengthSize + buffer.len > self.bb.len) {
            return error.OutOfBounds;
        }
        const byteLength: i32 = @intCast(buffer.len);
        std.mem.writeInt(i32, self.bb[offset .. offset + lengthSize], byteLength, .little);

        // Copy the actual bytes into the buffer after the length
        const start = offset + lengthSize;
        std.mem.copyForwards(u8, self.bb[start .. start + buffer.len], buffer);
    }

    pub fn getString(self: *Page, offset: usize) ![]const u8 {
        // Retrieve the byte slice from the offset using getBytes
        const buffer = try self.getBytes(offset);

        // Convert the byte slice to a string slice
        if (!std.unicode.utf8Validate(buffer)) {
            return error.InvalidUTF8;
        }

        return buffer;
    }

    pub fn setString(self: *Page, offset: usize, s: []const u8) !void {
        return self.setBytes(offset, s);
    }

    pub fn maxLength(strlen: usize) u32 {
        // Maximum bytes per character in UTF-8.
        const bytesPerChar: f32 = 4.0;

        // Size of an integer in bytes.
        const integerBytes: u32 = @sizeOf(i32);

        // Calculate the max length based on input string length and bytes per character.
        const result = integerBytes + @as(u32, @intCast(strlen)) + @as(u32, @intCast(bytesPerChar));
        return result;
    }

    fn contents(self: *Page) []u8 {
        // Return the whole buffer starting at position 0.
        return self.bb;
    }
};
