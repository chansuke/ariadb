const std = @import("std");

const BlockId = @import("block_id.zig").BlockId;
const Page = @import("page.zig").Page;

pub const FileMgr = struct {
    db_directory: std.fs.Dir,
    blocksize: i64,
    is_new: bool,
    openfiles: std.AutoHashMap([]const u8, std.fs.File),

    const Self = @This();

    // Initialize FileMgr with a directory path
    pub fn init(allocator: std.mem.Allocator, path: []const u8, blocksize_param: i64) FileMgr {
        // Attempt to open the directory to check if it exists
        //var dir_result = std.fs.cwd().openDir(path, .{});
        var dir: std.fs.Dir = undefined;

        // Check if the directory exists
        var is_new_param: bool = false;
        switch (std.fs.cwd().openDir(path, .{})) {
            error.FileNotFound => {
                // If the directory does not exist, set is_new to true and create the directory
                is_new_param = true;
                try std.fs.cwd().makeDir(path);
                // Open the newly created directory
                dir = try std.fs.cwd().openDir(path, .{});
            },
            // If the directory exists, assign it to dir
            else => |opened_dir| {
                dir = opened_dir;
            },
        }

        // Initialize the HashMap for open files
        const openfiles = std.HashMap([]const u8, std.fs.File).init(allocator);

        // If the directory is new, clean up temporary files
        if (is_new_param) {
            var it = dir.iterate();
            while (try it.next()) |entry| {
                const filename = entry.name;

                // Check if the filename starts with "temp"
                if (std.mem.startsWith(u8, filename, "temp")) {
                    // Construct the full path to the file and delete it
                    const file_path = try std.fs.path.join(allocator, &.{ path, filename });
                    defer allocator.free(file_path);
                    _ = std.fs.cwd().deleteFile(file_path) catch |err| {
                        if (err != error.FileNotFound) return err;
                    };
                }
            }
        }

        // Return the initialized FileMgr struct
        return FileMgr{
            .db_directory = dir,
            .blocksize = blocksize_param,
            .is_new = is_new_param,
            .openfiles = openfiles,
        };
    }

    // Clean up resources
    pub fn deinit(self: *Self) void {
        // Close all open files and deinitialize the map
        var it = self.openfiles.iterator();
        while (it.next()) |entry| {
            entry.value.close(); // Close each file handle
        }
        self.openfiles.deinit();
        self.db_directory.close(); // Close the directory handle
    }

    // Read data from a file into a page
    pub fn read(self: *Self, block: BlockId, page: *Page) !void {
        // Get the file associated with the block's filename
        const file = try self.getFile(block.filename);

        // Calculate the seek position based on the block number and block size
        const converted_block_num: u64 = @intCast(block.number());
        const converted_block_size: u64 = @intCast(self.blocksize);
        const position = converted_block_num * converted_block_size;

        // Seek to the correct position in the file
        try file.seekTo(position);

        // Read the file data into the page's contents
        try file.readAll(page.contents());
    }

    // Read data from a file into a page
    pub fn write(self: *Self, block: BlockId, page: *Page) !void {
        // Get the file associated with the block's filename
        const file = try self.getFile(block.filename);

        // Calculate the seek position based on the block number and block size
        const converted_block_num: u64 = @intCast(block.number());
        const converted_block_size: u64 = @intCast(self.blocksize);
        const position = converted_block_num * converted_block_size;

        // Seek to the correct position in the file
        try file.seekTo(position);

        // Read the file data into the page's contents
        try file.writeAll(page.contents());
    }

    pub fn append(self: *Self, allocator: *std.mem.Allocator, filename: []const u8) BlockId {
        const f = try self.db_directory.openFile(filename, .{ .read = true });

        // Retrieve the file's metadata to get the file size
        const file_info = try f.stat();
        const new_block_num = @as(i64, @intCast(file_info.size));

        const block: BlockId = .{
            .filename = filename,
            .block_num = new_block_num,
        };

        // Allocate a byte buffer of size `self.blocksize`
        const buffer = try allocator.alloc(u8, @intCast(self.blocksize));
        defer allocator.free(buffer);

        const file = try self.getFile(block.filename());

        // Seek to the correct position in the file
        try file.seek(block.number() * self.blocksize);

        // Read the file data into the page's contents
        try file.writeAll(buffer);

        return block;
    }

    pub fn length(self: *Self, filename: []const u8) i64 {
        const file = try self.getFile(filename);
        return file.length() / self.blocksize;
    }

    pub fn get_is_new(self: *Self) bool {
        return self.is_new;
    }

    pub fn get_blocksize(self: *Self) i64 {
        return self.blocksize;
    }

    // Open or get an existing file by its filename
    fn getFile(self: *Self, filename: []const u8) !std.fs.File {
        if (self.openfiles.get(filename)) |file| {
            return file;
        } else {
            // https://ziglang.org/documentation/master/std/#std.fs.File.OpenFlags
            // https://ziglang.org/documentation/master/std/#std.fs.File.OpenMode
            const file = try self.db_directory.openFile(filename, .{
                .mode = .read_write,
                .lock = .none,
            });
            try self.openfiles.put(filename, file);
            return file;
        }
    }
};
