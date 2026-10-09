const std = @import("std");

fn detectDevice(alloc: std.mem.Allocator) !struct { threads: u32, name: []u8 } {
    const count = std.Thread.getCpuCount() catch 1;
    const env = std.process.getEnvVarOwned(alloc, "AOL_DEVICE") catch null;
    if (env) |name| return .{ .threads = @intCast(count), .name = name };
    return .{ .threads = @intCast(count), .name = try alloc.dupe(u8, "cpu-auto") };
}

fn hashShare(worker: []const u8, job: u32, nonce: u64) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(worker);
    var buf: [32]u8 = undefined;
    const job_s = std.fmt.bufPrint(&buf, "{d}", .{job}) catch "0";
    hasher.update(job_s);
    var nonce_buf: [32]u8 = undefined;
    const nonce_s = std.fmt.bufPrint(&nonce_buf, "{d}", .{nonce}) catch "0";
    hasher.update(nonce_s);
    return hasher.finalResult();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 3333;
    var worker: []const u8 = "SteveCaseFan.rig1";
    var threads: ?u32 = null;
    var device: ?[]const u8 = null;
    var args = std.process.args();
    _ = args.skip();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--host")) host = args.next() orelse host;
        if (std.mem.eql(u8, arg, "--port")) port = std.fmt.parseInt(u16, args.next() orelse "3333", 10) catch 3333;
        if (std.mem.eql(u8, arg, "--worker")) worker = args.next() orelse worker;
        if (std.mem.eql(u8, arg, "--threads")) threads = std.fmt.parseInt(u32, args.next() orelse "1", 10) catch 1;
        if (std.mem.eql(u8, arg, "--device")) device = args.next();
    }
    const found = try detectDevice(alloc);
    const use_threads = threads orelse found.threads;
    const use_device = device orelse found.name;
    var gpu = false;
    var asic = false;
    if (std.fs.cwd().access("/dev/nvidia0", .{})) |_| gpu = true else |_| {}
    if (std.fs.cwd().access("/dev/dri/card0", .{})) |_| gpu = true else |_| {}
    if (std.fs.cwd().access("/dev/ttyUSB0", .{})) |_| asic = true else |_| {}
    const kind = if (std.mem.indexOf(u8, use_device, "asic") != null or asic) "asic" else if (std.mem.indexOf(u8, use_device, "gpu") != null or gpu) "gpu" else "cpu";
    std.debug.print("detected {d} threads, device {s}, class {s}\n", .{ found.threads, found.name, kind });
    std.debug.print("using {d} threads on {s} as {s} -> {s}:{d}\n", .{ use_threads, use_device, worker, host, port });
    const addr = try std.net.Address.parseIp4(host, port);
    const stream = try std.net.tcpConnectToAddress(addr);
    var login: [320]u8 = undefined;
    const sub = try std.fmt.bufPrint(&login, "{{\"id\":1,\"method\":\"mining.subscribe\",\"params\":[\"aol-miner/0.2 {s}\"]}}\n", .{kind});
    try stream.writeAll(sub);
    var reply: [512]u8 = undefined;
    const n = try stream.read(&reply);
    std.debug.print("subscribe: {s}\n", .{reply[0..n]});
    const auth = try std.fmt.bufPrint(&login, "{{\"id\":2,\"method\":\"mining.authorize\",\"params\":[\"{s}.{s}\",\"x\"]}}\n", .{ worker, kind });
    try stream.writeAll(auth);
    const n2 = try stream.read(&reply);
    std.debug.print("authorize: {s}\n", .{reply[0..n2]});
    var nonce: u64 = 0;
    while (nonce < 200000) : (nonce += 1) {
        const digest = hashShare(worker, 1, nonce);
        if (digest[0] == 0 and digest[1] == 0) {
            var submit: [128]u8 = undefined;
            const msg = try std.fmt.bufPrint(&submit, "{{\"id\":3,\"method\":\"mining.submit\",\"params\":[\"{s}\",\"1\",\"{d}\"]}}\n", .{ worker, nonce });
            try stream.writeAll(msg);
            const got = try stream.read(&reply);
            std.debug.print("share {d}: {s}\n", .{ nonce, reply[0..got] });
            break;
        }
    }
}
