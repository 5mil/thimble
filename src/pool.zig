const std = @import("std");

pub const Pool = struct {
    lock: std.Thread.Mutex = .{},
    job: u32 = 1,
    accepted: u64 = 0,
    rejected: u64 = 0,
    workers: std.ArrayList(Worker),
    alloc: std.mem.Allocator,

    pub const Worker = struct {
        name: []u8,
        threads: u32,
        device: []u8,
        shares: u64 = 0,
        seen: i64,
    };

    pub fn init(alloc: std.mem.Allocator) Pool {
        return .{ .workers = std.ArrayList(Worker).init(alloc), .alloc = alloc };
    }

    pub fn statusJson(self: *Pool, alloc: std.mem.Allocator) ![]u8 {
        self.lock.lock();
        defer self.lock.unlock();
        var out = std.ArrayList(u8).init(alloc);
        try out.writer().print("{{\"job\":{d},\"accepted\":{d},\"rejected\":{d},\"workers\":[", .{ self.job, self.accepted, self.rejected });
        for (self.workers.items, 0..) |w, i| {
            if (i != 0) try out.append(',');
            try out.writer().print("{{\"name\":\"{s}\",\"threads\":{d},\"device\":\"{s}\",\"shares\":{d}}}", .{ w.name, w.threads, w.device, w.shares });
        }
        try out.appendSlice("]}");
        return out.toOwnedSlice();
    }
};

pub var pool: Pool = undefined;

fn difficultyMet(digest: [32]u8) bool {
    return digest[0] == 0 and digest[1] == 0;
}

fn shareHash(worker: []const u8, job: u32, nonce: []const u8) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(worker);
    var job_buf: [16]u8 = undefined;
    const job_s = std.fmt.bufPrint(&job_buf, "{d}", .{job}) catch "0";
    hasher.update(job_s);
    hasher.update(nonce);
    return hasher.finalResult();
}

fn field(body: []const u8, key: []const u8, out: []u8) []u8 {
    var pat: [40]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "\"{s}\":\"", .{key}) catch return out[0..0];
    const at = std.mem.indexOf(u8, body, p) orelse return out[0..0];
    var i = at + p.len;
    var n: usize = 0;
    while (i < body.len and body[i] != '"' and n + 1 < out.len) : (i += 1) {
        out[n] = body[i];
        n += 1;
    }
    return out[0..n];
}

fn serveMiner(conn: std.net.Server.Connection) void {
    defer conn.stream.close();
    var buf: [1024]u8 = undefined;
    var worker_buf: [64]u8 = undefined;
    var worker_len: usize = 0;
    var have_worker = false;
    while (true) {
        const n = conn.stream.read(&buf) catch return;
        if (n == 0) return;
        const line = buf[0..n];
        var name: [64]u8 = undefined;
        var device: [64]u8 = undefined;
        var nonce: [64]u8 = undefined;
        const method = field(line, "method", &name);
        if (std.mem.eql(u8, method, "login")) {
            const who = field(line, "worker", &worker_buf);
            worker_len = who.len;
            const dev = field(line, "device", &device);
            const threads = std.fmt.parseInt(u32, field(line, "threads", &nonce), 10) catch 1;
            pool.lock.lock();
            pool.workers.append(.{
                .name = pool.alloc.dupe(u8, who) catch "",
                .threads = threads,
                .device = pool.alloc.dupe(u8, if (dev.len == 0) "manual" else dev) catch "",
                .seen = std.time.timestamp(),
            }) catch {};
            const job = pool.job;
            pool.lock.unlock();
            have_worker = who.len > 0;
            var reply: [160]u8 = undefined;
            const msg = std.fmt.bufPrint(&reply, "{{\"method\":\"job\",\"id\":{d},\"algo\":\"sha256d\",\"target\":\"0000\"}}\n", .{job}) catch return;
            _ = conn.stream.writeAll(msg) catch return;
        } else if (std.mem.eql(u8, method, "submit") and have_worker) {
            const nonce_s = field(line, "nonce", &nonce);
            const digest = shareHash(worker_buf[0..worker_len], pool.job, nonce_s);
            const ok = difficultyMet(digest);
            pool.lock.lock();
            if (ok) pool.accepted += 1 else pool.rejected += 1;
            if (ok) {
                for (pool.workers.items) |*w| if (std.mem.eql(u8, worker_buf[0..worker_len], w.name)) {
                    w.shares += 1;
                    w.seen = std.time.timestamp();
                };
            }
            pool.lock.unlock();
            _ = conn.stream.writeAll(if (ok) "{\"result\":true}\n" else "{\"result\":false,\"error\":\"low difficulty\"}\n") catch return;
        } else {
            _ = conn.stream.writeAll("{\"error\":\"login first\"}\n") catch return;
        }
    }
}

pub fn start() !void {
    const addr = try std.net.Address.parseIp4("0.0.0.0", 3333);
    var server = try addr.listen(.{ .reuse_address = true });
    std.debug.print("Mining pool on stratum://0.0.0.0:3333\n", .{});
    while (true) {
        const conn = server.accept() catch continue;
        const thread = try std.Thread.spawn(.{}, serveMiner, .{conn});
        thread.detach();
    }
}
