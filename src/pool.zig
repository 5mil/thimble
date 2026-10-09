const std = @import("std");

pub const algos = [_][]const u8{ "sha256d", "scrypt", "ethash", "kawpow", "randomx", "yescrypt" };
pub const ports = [_]u16{ 3333, 3334, 3335, 3336, 3337, 3338 };

pub const Pool = struct {
    lock: std.Thread.Mutex = .{},
    accepted: u64 = 0,
    rejected: u64 = 0,
    workers: std.ArrayList(Worker),
    alloc: std.mem.Allocator,

    pub const Worker = struct {
        name: []u8,
        algo: []u8,
        device: []u8,
        threads: u32,
        agent: []u8,
        shares: u64 = 0,
    };

    pub fn init(alloc: std.mem.Allocator) Pool {
        return .{ .workers = std.ArrayList(Worker).init(alloc), .alloc = alloc };
    }

    pub fn statusJson(self: *Pool, alloc: std.mem.Allocator) ![]u8 {
        self.lock.lock();
        defer self.lock.unlock();
        var out = std.ArrayList(u8).init(alloc);
        try out.appendSlice("{\"coin\":");
        const cfg = std.fs.cwd().readFileAlloc(alloc, "coin.cfg", 4096) catch "name=none\n";
        const name_at = std.mem.indexOf(u8, cfg, "name=") orelse 0;
        const name = if (name_at == 0 and !std.mem.startsWith(u8, cfg, "name=")) "none" else cfg[name_at + 5 .. std.mem.indexOfScalarPos(u8, cfg, name_at, '\n') orelse cfg.len];
        try out.writer().print("\"{s}\",\"algos\":[\"sha256d\",\"scrypt\",\"ethash\",\"kawpow\",\"randomx\",\"yescrypt\"],\"ports\":{{\"sha256d\":3333,\"scrypt\":3334,\"ethash\":3335,\"kawpow\":3336,\"randomx\":3337,\"yescrypt\":3338}},\"accepted\":", .{name});
        try out.writer().print("{d},\"rejected\":{d},\"workers\":[", .{ self.accepted, self.rejected });
        for (self.workers.items, 0..) |w, i| {
            if (i != 0) try out.append(',');
            try out.writer().print("{{\"name\":\"{s}\",\"algo\":\"{s}\",\"device\":\"{s}\",\"threads\":{d},\"agent\":\"{s}\",\"shares\":{d}}}", .{ w.name, w.algo, w.device, w.threads, w.agent, w.shares });
        }
        try out.appendSlice("]}");
        return out.toOwnedSlice();
    }
};

pub var pool: Pool = undefined;

fn firstQuoted(line: []const u8) []const u8 {
    const mark = std.mem.indexOf(u8, line, "[\"") orelse return "";
    const end = std.mem.indexOfScalarPos(u8, line, mark + 2, '"') orelse return "";
    return line[mark + 2 .. end];
}

fn jsonString(line: []const u8, key: []const u8, out: []u8) []u8 {
    var pat: [32]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "\"{s}\":", .{key}) catch return out[0..0];
    const at = std.mem.indexOf(u8, line, p) orelse return out[0..0];
    var i = at + p.len;
    while (i < line.len and line[i] == ' ') i += 1;
    if (i >= line.len) return out[0..0];
    if (line[i] == '"') {
        i += 1;
        var n: usize = 0;
        while (i < line.len and line[i] != '"' and n + 1 < out.len) : (i += 1) {
            out[n] = line[i];
            n += 1;
        }
        return out[0..n];
    }
    var n: usize = 0;
    while (i < line.len and line[i] != ',' and line[i] != '}' and n + 1 < out.len) : (i += 1) {
        out[n] = line[i];
        n += 1;
    }
    return out[0..n];
}

fn shareOk(algo: []const u8, worker: []const u8, nonce: []const u8) bool {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(algo);
    hasher.update(worker);
    hasher.update(nonce);
    const first = hasher.finalResult();
    var second = std.crypto.hash.sha2.Sha256.init(.{});
    second.update(&first);
    const digest = second.finalResult();
    return digest[0] == 0;
}

fn serve(conn: std.net.Server.Connection, algo: []const u8) void {
    defer conn.stream.close();
    var buf: [2048]u8 = undefined;
    var worker: [80]u8 = undefined;
    var worker_len: usize = 0;
    var device: [48]u8 = undefined;
    var device_len: usize = 11;
    const threads: u32 = 0;
    var agent: [48]u8 = undefined;
    var agent_len: usize = 7;
    @memcpy(device[0..11], "asic-or-gpu");
    @memcpy(agent[0..7], "stratum");
    var authorized = false;
    while (true) {
        const n = conn.stream.read(&buf) catch return;
        if (n == 0) return;
        const line = buf[0..n];
        var method_buf: [32]u8 = undefined;
        var id_buf: [16]u8 = undefined;
        const method = jsonString(line, "method", &method_buf);
        const id = jsonString(line, "id", &id_buf);
        var reply: [640]u8 = undefined;
        if (std.mem.eql(u8, method, "mining.subscribe")) {
            const ua = jsonString(line, "params", &agent);
            if (ua.len > 0) agent_len = @min(ua.len, agent.len);
            const msg = std.fmt.bufPrint(&reply, "{{\"id\":{s},\"result\":[[[\"mining.notify\",\"ae\"],[\"mining.set_difficulty\",\"ae\"]],\"ae01\",4],\"error\":null}}\n", .{if (id.len == 0) "1" else id}) catch return;
            _ = conn.stream.writeAll(msg) catch return;
            _ = conn.stream.writeAll("{\"id\":null,\"method\":\"mining.set_difficulty\",\"params\":[0.01]}\n") catch return;
            _ = conn.stream.writeAll("{\"id\":null,\"method\":\"mining.notify\",\"params\":[\"1\",\"0000000000000000000000000000000000000000000000000000000000000000\",\"01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff\",\"\",\"[]\",\"20000000\",\"1a00ffff\",\"00000000\",false]}\n") catch return;
        } else if (std.mem.eql(u8, method, "mining.authorize")) {
            const who = firstQuoted(line);
            worker_len = @min(who.len, worker.len);
            @memcpy(worker[0..worker_len], who[0..worker_len]);
            if (std.mem.indexOf(u8, line, "gpu")) |_| { @memcpy(device[0..3], "gpu"); device_len = 3; }
            if (std.mem.indexOf(u8, line, "asic")) |_| { @memcpy(device[0..4], "asic"); device_len = 4; }
            if (std.mem.indexOf(u8, line, "cpu")) |_| { @memcpy(device[0..3], "cpu"); device_len = 3; }
            authorized = worker_len > 0;
            pool.lock.lock();
            pool.workers.append(.{
                .name = pool.alloc.dupe(u8, worker[0..worker_len]) catch "",
                .algo = pool.alloc.dupe(u8, algo) catch "",
                .device = pool.alloc.dupe(u8, device[0..device_len]) catch "",
                .threads = threads,
                .agent = pool.alloc.dupe(u8, agent[0..agent_len]) catch "",
                .shares = 0,
            }) catch {};
            pool.lock.unlock();
            const msg = std.fmt.bufPrint(&reply, "{{\"id\":{s},\"result\":true,\"error\":null}}\n", .{if (id.len == 0) "2" else id}) catch return;
            _ = conn.stream.writeAll(msg) catch return;
        } else if (std.mem.eql(u8, method, "mining.submit") and authorized) {
            var nonce: [64]u8 = undefined;
            const nonce_s = jsonString(line, "params", &nonce);
            const ok = shareOk(algo, worker[0..worker_len], nonce_s);
            pool.lock.lock();
            if (ok) pool.accepted += 1 else pool.rejected += 1;
            if (ok) for (pool.workers.items) |*w| if (std.mem.eql(u8, w.name, worker[0..worker_len])) {
                w.shares += 1;
            };
            pool.lock.unlock();
            const msg = std.fmt.bufPrint(&reply, "{{\"id\":{s},\"result\":{s},\"error\":{s}}}\n", .{ if (id.len == 0) "3" else id, if (ok) "true" else "false", if (ok) "null" else "[23,\"low difficulty\",null]" }) catch return;
            _ = conn.stream.writeAll(msg) catch return;
        } else if (method.len == 0 and std.mem.indexOf(u8, line, "\"method\":\"login\"") != null) {
            const who = jsonString(line, "worker", &worker);
            worker_len = who.len;
            authorized = true;
            const msg = std.fmt.bufPrint(&reply, "{{\"method\":\"job\",\"algo\":\"{s}\",\"id\":1}}\n", .{algo}) catch return;
            _ = conn.stream.writeAll(msg) catch return;
        }
    }
}

fn listen(port: u16, algo: []const u8) void {
    const addr = std.net.Address.parseIp4("0.0.0.0", port) catch return;
    var server = addr.listen(.{ .reuse_address = true }) catch return;
    std.debug.print("Stratum {s} on 0.0.0.0:{d}\n", .{ algo, port });
    while (true) {
        const conn = server.accept() catch continue;
        const thread = std.Thread.spawn(.{}, serve, .{ conn, algo }) catch continue;
        thread.detach();
    }
}

pub fn start() !void {
    for (algos, ports) |algo, port| {
        const thread = try std.Thread.spawn(.{}, listen, .{ port, algo });
        thread.detach();
    }
}
