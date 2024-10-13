const std = @import("std");

const BlockId = struct {
    filename: []u8,
    block_num: u32,

    pub fn filename(self: BlockId) []u8 {
        return self.filename;
    }

    pub fn number(self: BlockId) u32 {
        return self.block_num;
    }

    pub fn equals(self: BlockId, other: BlockId) bool {
        return self.filename == other.filename and self.block_num == other.block_num;
    }

    pub fn toString(self: BlockId, allocator: *std.mem.Allocator) []u8 {
        const block_num_str = try std.fmt.allocPrint(allocator, "{d}", .{self.blknum});
        defer allocator.free(block_num_str);
        return try std.fmt.allocPrint(allocator, "{}-{}", .{ self.filename, block_num_str });
    }

    pub fn hashCode(self: BlockId, allocator: *std.mem.Allocator) !u32 {
        const block_id_str = try self.toString(allocator);
        defer allocator.free(block_id_str);

        var hasher = std.hash.Fnv1a_64.init();

        hasher.hash(block_id_str);

        return @intCast(hasher.finish());
    }
};
