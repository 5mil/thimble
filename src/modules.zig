const std = @import("std");

pub const Mod = struct {
    name: [24]u8 = undefined,
    name_len: usize = 0,
    algo: [16]u8 = undefined,
    algo_len: usize = 0,
    port: u16 = 0,
    on: bool = false,
    merge: [16]u8 = undefined,
    merge_len: usize = 0,
    bonus: u8 = 0,
    house: bool = false,
    height: u32 = 0,
    child_height: u32 = 0,
    state: [12]u8 = undefined,
    state_len: usize = 0,
    accepted: u64 = 0,
    house_shares: u64 = 0,
    source: [96]u8 = undefined,
    source_len: usize = 0,
    wallet: [64]u8 = undefined,
    wallet_len: usize = 0,
    stale: u64 = 0,
    duplicate: u64 = 0,
};

pub var mods: [8]Mod = undefined;
pub var count: usize = 0;
pub var house_on = false;

fn put(dst: []u8, src: []const u8) usize {
    const n = @min(dst.len, src.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

pub fn load() void {
    count = 0;
    const raw = std.fs.cwd().readFileAlloc(std.heap.page_allocator, "pools.cfg", 1 << 16) catch return;
    var it = std.mem.splitScalar(u8, raw, '\n');
    while (it.next()) |row| {
        if (row.len < 2) continue;
        if (row.len < 2 or row[0] == '#') {
            if (std.mem.indexOf(u8, row, "house") != null) house_on = std.mem.indexOf(u8, row, "1") != null;
            continue;
        }
        if (std.mem.startsWith(u8, row, "house") or std.mem.startsWith(u8, row, "data")) continue;
        if (count >= mods.len) continue;
        var parts = std.mem.splitScalar(u8, row, '\t');
        var m = &mods[count];
        m.name_len = put(&m.name, parts.next() orelse continue);
        m.algo_len = put(&m.algo, parts.next() orelse "sha256d");
        m.port = std.fmt.parseInt(u16, parts.next() orelse "0", 10) catch 0;
        m.on = std.mem.eql(u8, parts.next() orelse "0", "1");
        m.merge_len = put(&m.merge, parts.next() orelse "none");
        m.bonus = std.fmt.parseInt(u8, parts.next() orelse "0", 10) catch 0;
        m.source_len = put(&m.source, parts.next() orelse "");
        m.wallet_len = put(&m.wallet, parts.next() orelse "");
        m.house = house_on;
        m.state_len = put(&m.state, if (m.source_len == 0) "no source" else if (m.on) "up" else "off");
        var twin = false;
        for (mods[0..count]) |*old| {
            if (old.port == m.port and std.mem.eql(u8, old.name[0..old.name_len], m.name[0..m.name_len])) {
                if (m.source_len > 0) old.* = m.*;
                twin = true;
                break;
            }
        }
        if (!twin) count += 1;
    }
}

pub fn byPort(port: u16) ?*Mod {
    for (mods[0..count]) |*m| if (m.port == port and m.on) return m;
    return null;
}

pub fn credit(port: u16, worker: []const u8, diff: u32) void {
    const m = byPort(port) orelse return;
    m.accepted += 1;
    if (std.mem.eql(u8, worker, "house")) {
        m.house_shares += diff;
    }
}

pub fn bonusOf(port: u16) u64 {
    const m = byPort(port) orelse return 0;
    return m.house_shares * m.bonus / 100;
}

pub fn sentence(buf: []u8) []u8 {
    var out = std.ArrayList(u8).init(std.heap.page_allocator);
    if (count == 0) return std.fmt.bufPrint(buf, "No modules yet. Pool, then Settings.", .{}) catch buf[0..0];
    var up: usize = 0;
    var down: usize = 0;
    for (mods[0..count]) |m| {
        if (!m.on) continue;
        if (m.source_len == 0) down += 1 else up += 1;
    }
    out.writer().print("{d} modules. {d} with a source. {d} waiting.", .{ count, up, down }) catch {};
    const n = @min(out.items.len, buf.len);
    @memcpy(buf[0..n], out.items[0..n]);
    return buf[0..n];
}

pub fn line(buf: []u8) []u8 {
    var out = std.ArrayList(u8).init(std.heap.page_allocator);
    if (count == 0) return std.fmt.bufPrint(buf, "", .{}) catch buf[0..0];
    out.appendSlice("--- modules ---\n") catch {};
    for (mods[0..count]) |m| {
        const src = if (m.source_len == 0) "no source" else m.source[0..m.source_len];
        out.writer().print("{s}   {s}   {d}   {s}   merge {s}   {d}%   shares {d}\n", .{
            m.name[0..m.name_len],
            m.algo[0..m.algo_len],
            m.port,
            if (m.on) "running" else "stopped",
            m.merge[0..m.merge_len],
            m.bonus,
            m.accepted,
        }) catch {};
        out.writer().print("           source {s}\n", .{src}) catch {};
    }
    const n = @min(out.items.len, buf.len);
    @memcpy(buf[0..n], out.items[0..n]);
    return buf[0..n];
}
