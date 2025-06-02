const std = @import("std");

const FileMgr = @import("../src/file_mngr.zig").FileMgr;
const BlockId = @import("../src/block_id.zig").BlockId;
const Page = @import("../src/page.zig").Page;

test "test file manager" {
    // Use a more suitable allocator for this test since we're allocating pages of 400 bytes
    const allocator = std.testing.allocator;

    const db = "./testdb/filetest";
    const block_size = 400;

    var fm = try FileMgr.init(allocator, db, block_size);
    defer fm.deinit();
    const testfile: []const u8 = "testfile";
    const blk = try BlockId.init(testfile, 2);

    const pos1 = 88;
    const fm_block_size = fm.blocksize;
    // Check that the block size is non-negative before converting.
    if (fm_block_size < 0) {
        unreachable; // or handle the error as appropriate
    }
    const fm_block_size_usize: usize = @intCast(fm_block_size);
    var p1 = try Page.initWithSize(allocator, fm_block_size_usize);
    defer p1.deinit(allocator);

    try p1.setString(pos1, "abcdefghijklm");

    const size = p1.maxLength("abcdefghijklm".len);
    const pos2 = pos1 + size;
    try p1.setInt(pos2, 345);

    try fm.write(blk, &p1);

    // Use the same fm_block_size_usize for p2.
    var p2 = try Page.initWithSize(allocator, fm_block_size_usize);
    defer p2.deinit(allocator);
    try fm.read(blk, &p2);

    try std.testing.expectEqualStrings(try p2.getString(pos1), "abcdefghijklm");
    try std.testing.expectEqual(try p2.getInt(pos2), 345);
}
