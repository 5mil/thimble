const std = @import("std");

pub const State = enum { no_node, syncing, headers, pruned, ready, upstream };

pub const Job = struct {
    id: [16]u8 = [_]u8{0} ** 16,
    id_len: usize = 1,
    prevhash: [64]u8 = [_]u8{'0'} ** 64,
    version: [8]u8 = [_]u8{'2','0','0','0','0','0','0','0'},
    nbits: [8]u8 = [_]u8{'1','a','0','0','f','f','f','f'},
    ntime: [8]u8 = [_]u8{'0'} ** 8,
    height: u32 = 0,
    clean: bool = true,
};

pub const Source = struct {
    lock: std.Thread.Mutex = .{},
    state: State = .no_node,
    height: u32 = 0,
    peers: u32 = 0,
    ibd: bool = false,
    pruned: bool = false,
    job: Job = .{},
    upstream: [96]u8 = undefined,
    upstream_len: usize = 0,
    rpc: [128]u8 = undefined,
    rpc_len: usize = 0,
    wallet: [80]u8 = undefined,
    wallet_len: usize = 0,
    last_error: [80]u8 = undefined,
    last_error_len: usize = 0,
    blocks_found: u64 = 0,
};

pub var source: Source = .{};

fn copyEnv(name: []const u8, dst: []u8) usize {
    const v = std.process.getEnvVarOwned(std.heap.page_allocator, name) catch return 0;
    defer std.heap.page_allocator.free(v);
    const n = @min(v.len, dst.len);
    @memcpy(dst[0..n], v[0..n]);
    return n;
}

fn note(text: []const u8) void {
    const n = @min(text.len, source.last_error.len);
    @memcpy(source.last_error[0..n], text[0..n]);
    source.last_error_len = n;
}

pub var build_stage: [32]u8 = undefined;
pub var build_stage_len: usize = 0;
pub var build_detail: [120]u8 = undefined;
pub var build_detail_len: usize = 0;

pub fn setStage(stage: []const u8, detail: []const u8) void {
    const n = @min(stage.len, build_stage.len);
    @memcpy(build_stage[0..n], stage[0..n]);
    build_stage_len = n;
    const d = @min(detail.len, build_detail.len);
    @memcpy(build_detail[0..d], detail[0..d]);
    build_detail_len = d;
}

pub fn progress() u8 {
    if (build_stage_len == 0) return 0;
    const s = build_stage[0..build_stage_len];
    if (std.mem.eql(u8, s, "checking")) return 5;
    if (std.mem.eql(u8, s, "downloading")) return 15;
    if (std.mem.eql(u8, s, "cloned")) return 30;
    if (std.mem.eql(u8, s, "compiling")) return 55;
    if (std.mem.eql(u8, s, "compiled")) return 80;
    if (std.mem.eql(u8, s, "connecting")) return 90;
    if (std.mem.eql(u8, s, "ready")) return 100;
    if (std.mem.eql(u8, s, "failed")) return 0;
    return 10;
}

fn bar(pct: u8) [20]u8 {
    var out: [20]u8 = [_]u8{'.'} ** 20;
    const filled = @min(@as(usize, 20), @as(usize, pct) * 20 / 100);
    for (out[0..filled]) |*c| c.* = '#';
    return out;
}

pub fn stageLine(buf: []u8) []u8 {
    if (build_stage_len == 0) return std.fmt.bufPrint(buf, "codebase  none", .{}) catch buf[0..0];
    const pct = progress();
    const mark = bar(pct);
    return std.fmt.bufPrint(buf, "{d}% [{s}]  {s}  {s}", .{ pct, mark, build_stage[0..build_stage_len], if (build_detail_len > 0) build_detail[0..build_detail_len] else "" }) catch buf[0..0];
}

pub fn line(buf: []u8) []u8 {
    source.lock.lock();
    defer source.lock.unlock();
    const state = switch (source.state) {
        .no_node => "no node",
        .syncing => "syncing",
        .headers => "headers",
        .pruned => "pruned",
        .ready => "ready",
        .upstream => "upstream",
    };
    return std.fmt.bufPrint(buf, "chain  {s}  height {d}  peers {d}  ibd {s}  {s}", .{
        state,
        source.height,
        source.peers,
        if (source.ibd) "yes" else "no",
        if (source.last_error_len > 0) source.last_error[0..source.last_error_len] else "working",
    }) catch buf[0..0];
}

fn httpPost(alloc: std.mem.Allocator, url: []const u8, body: []const u8) ?[]u8 {
    // url is http://user:pass@host:port
    const at = std.mem.indexOfScalar(u8, url, '@') orelse return null;
    const scheme = std.mem.indexOf(u8, url, "://") orelse return null;
    const auth = url[scheme + 3 .. at];
    const hostport = url[at + 1 ..];
    const colon = std.mem.lastIndexOfScalar(u8, hostport, ':') orelse return null;
    const host = hostport[0..colon];
    const port = std.fmt.parseInt(u16, hostport[colon + 1 ..], 10) catch 8332;
    const addr = std.net.Address.parseIp4(host, port) catch blk: {
        const list = std.net.getAddressList(alloc, host, port) catch return null;
        defer list.deinit();
        if (list.addrs.len == 0) return null;
        break :blk list.addrs[0];
    };
    const stream = std.net.tcpConnectToAddress(addr) catch return null;
    defer stream.close();
    var auth_buf: [180]u8 = undefined;
    const b64 = std.base64.standard.Encoder.encode(&auth_buf, auth);
    var req: [1024]u8 = undefined;
    const head = std.fmt.bufPrint(&req, "POST / HTTP/1.1\r\nHost: {s}\r\nAuthorization: Basic {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ hostport, b64, body.len, body }) catch return null;
    stream.writeAll(head) catch return null;
    return stream.reader().readAllAlloc(alloc, 1 << 20) catch null;
}

fn jsonNum(text: []const u8, key: []const u8) ?u32 {
    var pat: [40]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "\"{s}\":", .{key}) catch return null;
    const at = std.mem.indexOf(u8, text, p) orelse return null;
    var i = at + p.len;
    while (i < text.len and (text[i] == ' ' or text[i] == '"')) i += 1;
    var n: u32 = 0;
    var any = false;
    while (i < text.len and text[i] >= '0' and text[i] <= '9') : (i += 1) {
        any = true;
        n = n * 10 + (text[i] - '0');
    }
    return if (any) n else null;
}

fn jsonBool(text: []const u8, key: []const u8) bool {
    var pat: [40]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "\"{s}\":true", .{key}) catch return false;
    return std.mem.indexOf(u8, text, p) != null;
}

fn pollRpc(alloc: std.mem.Allocator) void {
    const info = httpPost(alloc, source.rpc[0..source.rpc_len], "{\"jsonrpc\":\"1.0\",\"id\":\"h\",\"method\":\"getblockchaininfo\",\"params\":[]}") orelse {
        source.lock.lock();
        source.state = .no_node;
        note("rpc down");
        source.lock.unlock();
        return;
    };
    defer alloc.free(info);
    const height = jsonNum(info, "blocks") orelse 0;
    const headers = jsonNum(info, "headers") orelse height;
    const ibd = jsonBool(info, "initialblockdownload");
    const pruned = jsonBool(info, "pruned");
    const peers_raw = httpPost(alloc, source.rpc[0..source.rpc_len], "{\"jsonrpc\":\"1.0\",\"id\":\"p\",\"method\":\"getconnectioncount\",\"params\":[]}");
    const peers = if (peers_raw) |p| blk: {
        defer alloc.free(p);
        break :blk jsonNum(p, "result") orelse 0;
    } else 0;
    source.lock.lock();
    source.height = height;
    source.peers = peers;
    source.ibd = ibd;
    source.pruned = pruned;
    source.state = if (ibd) .syncing else if (pruned) .pruned else if (headers > height) .headers else .ready;
    note("rpc");
    source.lock.unlock();
    if (!ibd) pollTemplate(alloc);
}

fn pollTemplate(alloc: std.mem.Allocator) void {
    const body = "{\"jsonrpc\":\"1.0\",\"id\":\"t\",\"method\":\"getblocktemplate\",\"params\":[{\"rules\":[\"segwit\"]}]}";
    const raw = httpPost(alloc, source.rpc[0..source.rpc_len], body) orelse return;
    defer alloc.free(raw);
    source.lock.lock();
    defer source.lock.unlock();
    if (jsonNum(raw, "height")) |h| source.job.height = h;
    copyField(raw, "previousblockhash", &source.job.prevhash);
    copyField(raw, "bits", &source.job.nbits);
    var id: [16]u8 = undefined;
    const n = std.fmt.bufPrint(&id, "{d}", .{source.job.height}) catch return;
    @memcpy(source.job.id[0..n.len], n);
    source.job.id_len = n.len;
}

fn copyField(text: []const u8, key: []const u8, dst: []u8) void {
    var pat: [48]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "\"{s}\":\"", .{key}) catch return;
    const at = std.mem.indexOf(u8, text, p) orelse return;
    var i = at + p.len;
    var n: usize = 0;
    while (i < text.len and text[i] != '"' and n < dst.len) : (i += 1) {
        dst[n] = text[i];
        n += 1;
    }
}

fn upstreamHost(out_host: []u8, out_port: *u16) ?[]const u8 {
    var s = source.upstream[0..source.upstream_len];
    if (std.mem.indexOf(u8, s, "://")) |i| s = s[i + 3 ..];
    const colon = std.mem.lastIndexOfScalar(u8, s, ':') orelse return null;
    const n = @min(s[0..colon].len, out_host.len);
    @memcpy(out_host[0..n], s[0..colon]);
    out_port.* = std.fmt.parseInt(u16, s[colon + 1 ..], 10) catch 3333;
    return out_host[0..n];
}

fn pollUpstream(alloc: std.mem.Allocator) void {
    var host_buf: [80]u8 = undefined;
    var port: u16 = 3333;
    const host = upstreamHost(&host_buf, &port) orelse {
        source.lock.lock();
        source.state = .no_node;
        note("bad upstream");
        source.lock.unlock();
        return;
    };
    const addr = std.net.Address.parseIp4(host, port) catch blk: {
        const list = std.net.getAddressList(alloc, host, port) catch {
            source.lock.lock();
            source.state = .no_node;
            note("upstream dns");
            source.lock.unlock();
            return;
        };
        defer list.deinit();
        if (list.addrs.len == 0) return;
        break :blk list.addrs[0];
    };
    const stream = std.net.tcpConnectToAddress(addr) catch {
        source.lock.lock();
        source.state = .no_node;
        note("upstream down");
        source.lock.unlock();
        return;
    };
    defer stream.close();
    stream.writeAll("{\"id\":1,\"method\":\"mining.subscribe\",\"params\":[\"aol-host\"]}\n{\"id\":2,\"method\":\"mining.authorize\",\"params\":[\"aol.party\",\"x\"]}\n") catch return;
    source.lock.lock();
    source.state = .upstream;
    source.peers = 1;
    note("upstream");
    source.lock.unlock();
    var buf: [4096]u8 = undefined;
    const n = stream.read(&buf) catch return;
    if (std.mem.indexOf(u8, buf[0..n], "mining.notify")) |_| {
        source.lock.lock();
        source.job.id_len = 1;
        source.job.id[0] = 'u';
        source.height += 1;
        source.lock.unlock();
    }
}

fn watch() void {
    const alloc = std.heap.page_allocator;
    while (true) {
        if (source.rpc_len > 8) pollRpc(alloc) else if (source.upstream_len > 3) pollUpstream(alloc) else {
            source.lock.lock();
            source.state = .no_node;
            note("set AOL_RPC or AOL_UPSTREAM");
            source.lock.unlock();
        }
        std.time.sleep(15 * std.time.ns_per_s);
    }
}

pub fn start() void {
    source.rpc_len = copyEnv("AOL_RPC", &source.rpc);
    source.upstream_len = copyEnv("AOL_UPSTREAM", &source.upstream);
    source.wallet_len = copyEnv("AOL_WALLET", &source.wallet);
    const thread = std.Thread.spawn(.{}, watch, .{}) catch return;
    thread.detach();
}

pub fn currentJob() Job {
    source.lock.lock();
    defer source.lock.unlock();
    return source.job;
}

pub fn submitUpstream(worker: []const u8, job: []const u8, nonce: []const u8) bool {
    var host_buf: [80]u8 = undefined;
    var port: u16 = 3333;
    const host = upstreamHost(&host_buf, &port) orelse return false;
    const addr = std.net.Address.parseIp4(host, port) catch return false;
    const stream = std.net.tcpConnectToAddress(addr) catch return false;
    defer stream.close();
    var msg: [400]u8 = undefined;
    const payload = std.fmt.bufPrint(&msg, "{{\"id\":9,\"method\":\"mining.submit\",\"params\":[\"{s}\",\"{s}\",\"{s}\"]}}\n", .{ worker, job, nonce }) catch return false;
    stream.writeAll(payload) catch return false;
    var buf: [256]u8 = undefined;
    const n = stream.read(&buf) catch return false;
    return std.mem.indexOf(u8, buf[0..n], "true") != null;
}
