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

    // Clean up allocated memory
    pub fn deinit(self: *Page, allocator: std.mem.Allocator) void {
        allocator.free(self.bb);
    }

    // Create log pages.
    pub fn initWithBytes(buffer: []const u8) !Page {
        return Page{ .bb = buffer };
    }

    pub fn getInt(self: *Page, offset: usize) !i64 {
        if (offset + @sizeOf(i64) > self.bb.len) {
            return error.OutOfBounds;
        }

        return std.mem.readInt(i64, self.bb[offset..offset + @sizeOf(i64)][0..@sizeOf(i64)], .little);
    }

    pub fn setInt(self: *Page, offset: usize, n: i64) !void {
        if (offset + @sizeOf(i64) > self.bb.len) {
            return error.OutOfBounds;
        }
        std.mem.writeInt(i64, self.bb[offset..offset + @sizeOf(i64)][0..@sizeOf(i64)], n, .little);
    }

    pub fn getBytes(self: *Page, offset: usize) ![]u8 {
        if (offset + @sizeOf(i32) > self.bb.len) {
            return error.OutOfBounds;
        }

        const length = std.mem.readInt(i32, self.bb[offset..offset + @sizeOf(i32)][0..@sizeOf(i32)], .little);
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
        std.mem.writeInt(i32, self.bb[offset..offset + lengthSize][0..lengthSize], byteLength, .little);

        // Copy the actual bytes into the buffer after the length
        const start = offset + lengthSize;
        std.mem.copyForwards(u8, self.bb[start .. start + buffer.len], buffer);
    }

    pub fn getString(self: *Page, offset: usize) ![]const u8 {
        // Retrieve the byte slice from the offset using getBytes
        const buffer = try self.getBytes(offset);

        // Convert the byte slice to a string slice
        if (!std.unicode.utf8ValidateSlice(buffer)) {
            return error.InvalidUTF8;
        }

        return buffer;
    }

    pub fn setString(self: *Page, offset: usize, s: []const u8) !void {
        return self.setBytes(offset, s);
    }

    pub fn maxLength(self: *Page, strlen: usize) u32 {
        _ = self;
        // Size of an integer in bytes for length prefix
        const integerBytes: u32 = @sizeOf(i32);

        // Calculate the max length based on input string length
        const result = integerBytes + @as(u32, @intCast(strlen));
        return result;
    }

    pub fn contents(self: *Page) []u8 {
        // Return the whole buffer starting at position 0.
        return self.bb;
    }
};
