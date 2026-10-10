const std = @import("std");
const chain = @import("chain.zig");
const modules = @import("modules.zig");

pub const algos = [_][]const u8{ "sha256d", "scrypt", "ethash", "kawpow", "randomx", "yescrypt" };
pub const ports = [_]u16{ 3333, 3334, 3335, 3336, 3337, 3338 };

pub const Pool = struct {
    lock: std.Thread.Mutex = .{},
    accepted: u64 = 0,
    rejected: u64 = 0,
    blocks: u64 = 0,
    workers: std.ArrayList(Worker),
    alloc: std.mem.Allocator,

    pub const Worker = struct {
        name: []u8,
        party: []u8,
        algo: []u8,
        device: []u8,
        threads: u32,
        agent: []u8,
        shares: u64 = 0,
        seen: i64 = 0,
        diff: u32 = 1,
        balance: u64 = 0,
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
        try out.writer().print("{d},\"rejected\":{d},\"party\":[", .{ self.accepted, self.rejected });
        var seen_party = std.ArrayList([]const u8).init(alloc);
        defer seen_party.deinit();
        var first_party = true;
        for (self.workers.items) |w| {
            var known = false;
            for (seen_party.items) |p| {
                if (std.mem.eql(u8, p, w.party)) known = true;
            }
            if (known) continue;
            try seen_party.append(w.party);
            var total: u64 = 0;
            for (self.workers.items) |m| {
                if (std.mem.eql(u8, m.party, w.party)) total += m.shares;
            }
            if (!first_party) try out.append(',');
            first_party = false;
            try out.writer().print("{{\"name\":\"{s}\",\"shares\":{d}}}", .{ clean(w.party), total });
        }
        try out.appendSlice("],\"workers\":[");
        for (self.workers.items, 0..) |w, i| {
            if (i != 0) try out.append(',');
            try out.writer().print("{{\"name\":\"{s}\",\"party\":\"{s}\",\"algo\":\"{s}\",\"device\":\"{s}\",\"threads\":{d},\"agent\":\"{s}\",\"shares\":{d}}}", .{ clean(w.name), clean(w.party), clean(w.algo), clean(w.device), w.threads, clean(w.agent), w.shares });
        }
        try out.appendSlice("]}");
        return out.toOwnedSlice();
    }
};

pub var pool: Pool = undefined;

pub fn reportText(alloc: std.mem.Allocator) ![]u8 {
    pool.lock.lock();
    defer pool.lock.unlock();
    var out = std.ArrayList(u8).init(alloc);
    try out.writer().print("network  host up  ports 3333-3338\n", .{});
    var chain_buf: [160]u8 = undefined;
    try out.writer().print("{s}\n", .{chain.line(&chain_buf)});
    var mod_buf: [640]u8 = undefined;
    try out.appendSlice(modules.line(&mod_buf));
    try out.writer().print("accepted {d}  rejected {d}  blocks {d}  house bonus units {d}\nworkers {d}\n", .{ pool.accepted, pool.rejected, pool.blocks, modules.bonusOf(3333) + modules.bonusOf(3334), pool.workers.items.len });
    for (pool.workers.items) |w| {
        try out.writer().print("{s}  party {s}  {s}  shares {d}  {s}\n", .{ w.name, w.party, w.algo, w.shares, w.device });
    }
    return out.toOwnedSlice();
}

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

fn clean(text: []const u8) []const u8 {
    for (text) |c| if (c == '"' or c == '\\' or c < 32) return "bad";
    return text;
}

fn partyOf(name: []const u8) []const u8 {
    const dot = std.mem.indexOfScalar(u8, name, '.') orelse return "lobby";
    if (dot == 0) return "lobby";
    return name[0..dot];
}

fn loadParty() void {
    const raw = std.fs.cwd().readFileAlloc(pool.alloc, "party.db", 1 << 20) catch return;
    var it = std.mem.splitScalar(u8, raw, '\n');
    while (it.next()) |line| {
        if (line.len < 3) continue;
        var parts = std.mem.splitScalar(u8, line, '\t');
        const name = parts.next() orelse continue;
        const party = parts.next() orelse "lobby";
        const algo = parts.next() orelse "sha256d";
        const shares = std.fmt.parseInt(u64, parts.next() orelse "0", 10) catch 0;
        pool.accepted += shares;
        pool.workers.append(.{
            .name = pool.alloc.dupe(u8, name) catch "",
            .party = pool.alloc.dupe(u8, party) catch "",
            .algo = pool.alloc.dupe(u8, algo) catch "",
            .device = pool.alloc.dupe(u8, "saved") catch "",
            .threads = 0,
            .agent = pool.alloc.dupe(u8, "disk") catch "",
            .shares = shares,
        }) catch {};
    }
}

fn saveParty() void {
    var buf = std.ArrayList(u8).init(pool.alloc);
    defer buf.deinit();
    for (pool.workers.items) |w| {
        buf.writer().print("{s}\t{s}\t{s}\t{d}\n", .{ w.name, w.party, w.algo, w.shares }) catch return;
    }
    const tmp = "party.db.tmp";
    var file = std.fs.cwd().createFile(tmp, .{}) catch return;
    file.writeAll(buf.items) catch {
        file.close();
        return;
    };
    file.close();
    std.fs.cwd().rename(tmp, "party.db") catch {
        var direct = std.fs.cwd().createFile("party.db", .{}) catch return;
        defer direct.close();
        direct.writeAll(buf.items) catch return;
    };
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
            const start_diff: u32 = if (std.mem.eql(u8, algo, "sha256d")) 1024 else 1;
            var diff_msg: [80]u8 = undefined;
            const dline = std.fmt.bufPrint(&diff_msg, "{{\"id\":null,\"method\":\"mining.set_difficulty\",\"params\":[{d}]}}\n", .{start_diff}) catch return;
            _ = conn.stream.writeAll(dline) catch return;
            const job = chain.currentJob();
            var note: [420]u8 = undefined;
            const nline = std.fmt.bufPrint(&note, "{{\"id\":null,\"method\":\"mining.notify\",\"params\":[\"{s}\",\"{s}\",\"01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff\",\"\",\"[]\",\"{s}\",\"{s}\",\"{s}\",false]}}\n", .{ job.id[0..job.id_len], job.prevhash[0..64], job.version[0..8], job.nbits[0..8], job.ntime[0..8] }) catch return;
            _ = conn.stream.writeAll(nline) catch return;
        } else if (std.mem.eql(u8, method, "mining.authorize")) {
            const who = firstQuoted(line);
            worker_len = @min(who.len, worker.len);
            @memcpy(worker[0..worker_len], who[0..worker_len]);
            if (std.mem.indexOf(u8, line, "gpu")) |_| { @memcpy(device[0..3], "gpu"); device_len = 3; }
            if (std.mem.indexOf(u8, line, "asic")) |_| { @memcpy(device[0..4], "asic"); device_len = 4; }
            if (std.mem.indexOf(u8, line, "cpu")) |_| { @memcpy(device[0..3], "cpu"); device_len = 3; }
            authorized = worker_len > 0;
            const party = partyOf(worker[0..worker_len]);
            var existing = false;
            pool.lock.lock();
            for (pool.workers.items) |*w| if (std.mem.eql(u8, w.name, worker[0..worker_len])) {
                w.device = pool.alloc.dupe(u8, device[0..device_len]) catch w.device;
                existing = true;
            };
            if (!existing) pool.workers.append(.{
                .name = pool.alloc.dupe(u8, worker[0..worker_len]) catch "",
                .party = pool.alloc.dupe(u8, party) catch "",
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
            const job = chain.currentJob();
            const job_id = job.id[0..job.id_len];
            const on_job = nonce_s.len > 0 and (job_id.len == 0 or std.mem.indexOf(u8, line, job_id) != null or job_id[0] == 'u' or job_id[0] == 0);
            var ok = on_job and shareOk(algo, worker[0..worker_len], nonce_s);
            if (chain.source.state == .upstream) ok = chain.submitUpstream(worker[0..worker_len], job_id, nonce_s);
            var network = false;
            if (ok and chain.source.state == .ready and chain.source.height > 0) network = true;
            pool.lock.lock();
            if (ok) pool.accepted += 1 else pool.rejected += 1;
            if (network) pool.blocks += 1;
            if (ok) for (pool.workers.items) |*w| if (std.mem.eql(u8, w.name, worker[0..worker_len])) {
                w.shares += 1;
                w.balance += w.diff;
                w.seen = std.time.timestamp();
                if (w.shares % 8 == 0 and w.diff < 65536) w.diff *= 2;
                modules.credit(portOf(algo), worker[0..worker_len], w.diff);
            };
            pool.lock.unlock();
            if (ok) saveParty();
            writePayouts();
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

fn writePayouts() void {
    var buf = std.ArrayList(u8).init(pool.alloc);
    defer buf.deinit();
    buf.appendSlice("# screen  balance  min 1000 before a send\n") catch return;
    for (pool.workers.items) |w| {
        buf.writer().print("{s}\t{d}\n", .{ w.name, w.balance }) catch return;
    }
    var file = std.fs.cwd().createFile("payouts.cfg.tmp", .{}) catch return;
    file.writeAll(buf.items) catch {
        file.close();
        return;
    };
    file.close();
    std.fs.cwd().rename("payouts.cfg.tmp", "payouts.cfg") catch {};
}

fn portOf(algo: []const u8) u16 {
    for (modules.mods[0..modules.count]) |m| if (std.mem.eql(u8, m.algo[0..m.algo_len], algo)) return m.port;
    for (algos, ports) |a, p| if (std.mem.eql(u8, a, algo)) return p;
    return 0;
}

fn houseMine() void {
    while (true) {
        if (modules.house_on and chain.source.state != .no_node) {
            modules.credit(3333, "house", 1);
            pool.lock.lock();
            var found = false;
            for (pool.workers.items) |*w| if (std.mem.eql(u8, w.name, "house")) {
                w.shares += 1;
                w.balance += 1;
                found = true;
            };
            if (!found) pool.workers.append(.{
                .name = pool.alloc.dupe(u8, "house") catch "",
                .party = pool.alloc.dupe(u8, "house") catch "",
                .algo = pool.alloc.dupe(u8, "sha256d") catch "",
                .device = pool.alloc.dupe(u8, "host") catch "",
                .threads = 1,
                .agent = pool.alloc.dupe(u8, "house") catch "",
                .shares = 1,
                .diff = 1,
            }) catch {};
            pool.lock.unlock();
            saveParty();
        }
        std.time.sleep(30 * std.time.ns_per_s);
    }
}

pub fn start() !void {
    chain.start();
    modules.load();
    loadParty();
    if (modules.house_on) {
        const house = try std.Thread.spawn(.{}, houseMine, .{});
        house.detach();
    }
    var enabled = [_]bool{true} ** ports.len;
    if (std.fs.cwd().readFileAlloc(pool.alloc, "pools.cfg", 1 << 16)) |raw| {
        for (&enabled) |*on| on.* = false;
        var it = std.mem.splitScalar(u8, raw, '\n');
        while (it.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;
            var parts = std.mem.splitScalar(u8, line, '\t');
            _ = parts.next();
            _ = parts.next();
            const port = std.fmt.parseInt(u16, parts.next() orelse "0", 10) catch 0;
            const on = std.mem.eql(u8, parts.next() orelse "0", "1");
            if (!on) continue;
            for (ports, 0..) |p, i| {
                if (p == port) enabled[i] = true;
            }
        }
        var any = false;
        for (enabled) |on| {
            if (on) any = true;
        }
        if (!any) {
            for (&enabled) |*on| on.* = true;
        }
    } else |_| {}
    for (algos, ports, enabled) |algo, port, on| {
        if (!on) continue;
        const thread = try std.Thread.spawn(.{}, listen, .{ port, algo });
        thread.detach();
    }
}
