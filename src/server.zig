const std = @import("std");
const pool = @import("pool.zig");

const rooms = [_][]const u8{ "Lobby", "Thirtysomething", "Computer Help", "Sports Bar", "New Member Lounge" };

const User = struct { id: u32, name: []u8, salt: []u8, hash: []u8, created: i64 };
const Session = struct { token: []u8, user_id: u32, seen: i64 };
const Message = struct { id: u32, room: []u8, user_id: u32, body: []u8, created: i64 };
const Mail = struct { id: u32, from_id: u32, to_id: u32, subject: []u8, body: []u8, unread: bool, created: i64 };

const Store = struct {
    alloc: std.mem.Allocator,
    lock: std.Thread.Mutex = .{},
    users: std.ArrayList(User),
    sessions: std.ArrayList(Session),
    messages: std.ArrayList(Message),
    mail: std.ArrayList(Mail),
    next_user: u32 = 1,
    next_msg: u32 = 1,
    next_mail: u32 = 1,
    path: []const u8,

    fn init(alloc: std.mem.Allocator, path: []const u8) Store {
        return .{
            .alloc = alloc,
            .users = std.ArrayList(User).init(alloc),
            .sessions = std.ArrayList(Session).init(alloc),
            .messages = std.ArrayList(Message).init(alloc),
            .mail = std.ArrayList(Mail).init(alloc),
            .path = path,
        };
    }

    fn load(self: *Store) !void {
        const file = std.fs.cwd().openFile(self.path, .{}) catch return;
        defer file.close();
        const raw = try file.readToEndAlloc(self.alloc, 8 << 20);
        defer self.alloc.free(raw);
        var it = std.mem.splitScalar(u8, raw, '\n');
        while (it.next()) |line| {
            if (line.len < 2) continue;
            var parts = std.mem.splitScalar(u8, line, '\t');
            const kind = parts.next() orelse continue;
            if (std.mem.eql(u8, kind, "user")) {
                const id = try std.fmt.parseInt(u32, parts.next() orelse continue, 10);
                try self.users.append(.{
                    .id = id,
                    .name = try self.alloc.dupe(u8, parts.next() orelse continue),
                    .salt = try self.alloc.dupe(u8, parts.next() orelse continue),
                    .hash = try self.alloc.dupe(u8, parts.next() orelse continue),
                    .created = try std.fmt.parseInt(i64, parts.next() orelse "0", 10),
                });
                self.next_user = @max(self.next_user, id + 1);
            } else if (std.mem.eql(u8, kind, "msg")) {
                const id = try std.fmt.parseInt(u32, parts.next() orelse continue, 10);
                try self.messages.append(.{
                    .id = id,
                    .room = try self.alloc.dupe(u8, parts.next() orelse continue),
                    .user_id = try std.fmt.parseInt(u32, parts.next() orelse "0", 10),
                    .body = try unescape(self.alloc, parts.next() orelse ""),
                    .created = try std.fmt.parseInt(i64, parts.next() orelse "0", 10),
                });
                self.next_msg = @max(self.next_msg, id + 1);
            } else if (std.mem.eql(u8, kind, "mail")) {
                const id = try std.fmt.parseInt(u32, parts.next() orelse continue, 10);
                try self.mail.append(.{
                    .id = id,
                    .from_id = try std.fmt.parseInt(u32, parts.next() orelse "0", 10),
                    .to_id = try std.fmt.parseInt(u32, parts.next() orelse "0", 10),
                    .subject = try unescape(self.alloc, parts.next() orelse ""),
                    .body = try unescape(self.alloc, parts.next() orelse ""),
                    .unread = std.mem.eql(u8, parts.next() orelse "1", "1"),
                    .created = try std.fmt.parseInt(i64, parts.next() orelse "0", 10),
                });
                self.next_mail = @max(self.next_mail, id + 1);
            }
        }
    }

    fn save(self: *Store) !void {
        var file = try std.fs.cwd().createFile(self.path, .{});
        defer file.close();
        var buf = std.ArrayList(u8).init(self.alloc);
        defer buf.deinit();
        for (self.users.items) |u| {
            try buf.writer().print("user\t{d}\t{s}\t{s}\t{s}\t{d}\n", .{ u.id, u.name, u.salt, u.hash, u.created });
        }
        for (self.messages.items) |m| {
            const body = try escape(self.alloc, m.body);
            defer self.alloc.free(body);
            try buf.writer().print("msg\t{d}\t{s}\t{d}\t{s}\t{d}\n", .{ m.id, m.room, m.user_id, body, m.created });
        }
        for (self.mail.items) |m| {
            const subject = try escape(self.alloc, m.subject);
            defer self.alloc.free(subject);
            const body = try escape(self.alloc, m.body);
            defer self.alloc.free(body);
            try buf.writer().print("mail\t{d}\t{d}\t{d}\t{s}\t{s}\t{s}\t{d}\n", .{ m.id, m.from_id, m.to_id, subject, body, if (m.unread) "1" else "0", m.created });
        }
        try file.writeAll(buf.items);
    }
};

fn escape(alloc: std.mem.Allocator, text: []const u8) ![]u8 {
    var out = std.ArrayList(u8).init(alloc);
    for (text) |c| {
        if (c == '\\' or c == '\t' or c == '\n' or c == '\r') try out.append('\\');
        try out.append(if (c == '\n' or c == '\r' or c == '\t') ' ' else c);
    }
    return out.toOwnedSlice();
}

fn unescape(alloc: std.mem.Allocator, text: []const u8) ![]u8 {
    return alloc.dupe(u8, text);
}

fn validName(name: []const u8) bool {
    if (name.len < 3 or name.len > 16) return false;
    if (!std.ascii.isAlphabetic(name[0])) return false;
    for (name) |c| if (!std.ascii.isAlphanumeric(c)) return false;
    return true;
}

fn hashPassword(password: []const u8, salt: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    std.crypto.pwhash.pbkdf2(&out, password, salt, 120_000, std.crypto.auth.hmac.sha2.HmacSha256) catch unreachable;
    return out;
}

fn hex32(raw: [32]u8) [64]u8 {
    const digits = "0123456789abcdef";
    var out: [64]u8 = undefined;
    for (raw, 0..) |b, i| {
        out[i * 2] = digits[b >> 4];
        out[i * 2 + 1] = digits[b & 0xf];
    }
    return out;
}

fn hexAlloc(alloc: std.mem.Allocator, raw: []const u8) ![]u8 {
    const digits = "0123456789abcdef";
    var out = try alloc.alloc(u8, raw.len * 2);
    for (raw, 0..) |b, i| {
        out[i * 2] = digits[b >> 4];
        out[i * 2 + 1] = digits[b & 0xf];
    }
    return out;
}

fn findUser(store: *Store, name: []const u8) ?usize {
    for (store.users.items, 0..) |u, i| if (std.ascii.eqlIgnoreCase(u.name, name)) return i;
    return null;
}

fn userById(store: *Store, id: u32) ?User {
    for (store.users.items) |u| if (u.id == id) return u;
    return null;
}

fn auth(store: *Store, header: []const u8) ?User {
    const prefix = "Bearer ";
    if (!std.mem.startsWith(u8, header, prefix)) return null;
    const token = header[prefix.len..];
    for (store.sessions.items) |*s| {
        if (std.mem.eql(u8, s.token, token)) {
            s.seen = std.time.timestamp();
            return userById(store, s.user_id);
        }
    }
    return null;
}

fn jsonString(alloc: std.mem.Allocator, text: []const u8) ![]u8 {
    var out = std.ArrayList(u8).init(alloc);
    try out.append('"');
    for (text) |c| {
        if (c == '"' or c == '\\') try out.append('\\');
        try out.append(if (c < 32) ' ' else c);
    }
    try out.append('"');
    return out.toOwnedSlice();
}

fn formOrJson(body: []const u8, key: []const u8, alloc: std.mem.Allocator) ![]u8 {
    if (std.mem.indexOf(u8, body, "\":\"")) |_| return field(body, key, alloc);
    var pat: [40]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "{s}=", .{key}) catch return alloc.dupe(u8, "");
    const at = std.mem.indexOf(u8, body, p) orelse return alloc.dupe(u8, "");
    const rest = body[at + p.len ..];
    const end = std.mem.indexOfScalar(u8, rest, '&') orelse rest.len;
    return alloc.dupe(u8, rest[0..end]);
}

fn field(body: []const u8, key: []const u8, alloc: std.mem.Allocator) ![]u8 {
    var pat_buf: [40]u8 = undefined;
    const pat = std.fmt.bufPrint(&pat_buf, "\"{s}\":\"", .{key}) catch return alloc.dupe(u8, "");
    const start = std.mem.indexOf(u8, body, pat) orelse return alloc.dupe(u8, "");
    var i = start + pat.len;
    var out = std.ArrayList(u8).init(alloc);
    while (i < body.len and body[i] != '"') : (i += 1) {
        if (body[i] == '\\' and i + 1 < body.len) i += 1;
        try out.append(body[i]);
    }
    return out.toOwnedSlice();
}

fn handle(store: *Store, alloc: std.mem.Allocator, method: []const u8, path: []const u8, headers: []const u8, body: []const u8) ![]u8 {
    if (std.mem.eql(u8, path, "/admin")) {
        const page = "<html><body style=\"background:#1a2420;color:#d7d2c8;font-family:Georgia,serif\"><h1>Pool admin</h1><p>Paste a compatible coin repo. The host clones it and points the pool at that name.</p><form method=\"POST\" action=\"/api/admin/coin\">Admin token <input name=\"token\"><br>Repo <input name=\"repo\" size=\"60\" placeholder=\"https://github.com/5mil/orthal.git\"><br><button>Build pool</button></form></body></html>";
        return std.fmt.allocPrint(alloc, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ page.len, page });
    }
    if (std.mem.eql(u8, path, "/api/admin/coin")) {
        const token = formOrJson(body, "token", alloc) catch "";
        const repo = formOrJson(body, "repo", alloc) catch "";
        const expected = std.posix.getenv("AOL_ADMIN") orelse "lobby";
        if (!std.mem.eql(u8, token, expected) or !std.mem.startsWith(u8, repo, "https://")) {
            const payload = "{\"ok\":false,\"error\":\"Admin token or https repo required.\"}";
            return std.fmt.allocPrint(alloc, "HTTP/1.1 403 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ payload.len, payload });
        }
        const name = std.fs.path.stem(repo);
        const dest = try std.fmt.allocPrint(alloc, "coin-src/{s}", .{name});
        var child = std.process.Child.init(&.{ "git", "clone", "--depth", "1", repo, dest }, alloc);
        const term = child.spawnAndWait() catch {
            const payload = "{\"ok\":false,\"error\":\"git failed to start\"}";
            return std.fmt.allocPrint(alloc, "HTTP/1.1 500 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ payload.len, payload });
        };
        if (term != .Exited or term.Exited != 0) {
            const payload = "{\"ok\":false,\"error\":\"clone failed\"}";
            return std.fmt.allocPrint(alloc, "HTTP/1.1 502 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ payload.len, payload });
        }
        var file = try std.fs.cwd().createFile("coin.cfg", .{});
        defer file.close();
        try file.writer().print("name={s}\nrepo={s}\npath={s}\n", .{ name, repo, dest });
        const payload = try std.fmt.allocPrint(alloc, "{{\"ok\":true,\"coin\":\"{s}\",\"path\":\"{s}\"}}", .{ name, dest });
        return std.fmt.allocPrint(alloc, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ payload.len, payload });
    }
    if (std.mem.eql(u8, path, "/api/pool")) {
        const payload = try pool.pool.statusJson(alloc);
        return std.fmt.allocPrint(alloc, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ payload.len, payload });
    }
    if (std.mem.eql(u8, method, "GET") and (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/index.html"))) {
        const page = std.fs.cwd().readFileAlloc(alloc, "index.html", 1 << 20) catch "<h1>index.html missing</h1>";
        return std.fmt.allocPrint(alloc, "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ page.len, page });
    }
    const auth_header = blk: {
        var it = std.mem.splitSequence(u8, headers, "\r\n");
        while (it.next()) |line| if (std.ascii.startsWithIgnoreCase(line, "Authorization:")) break :blk std.mem.trim(u8, line[14..], " ");
        break :blk "";
    };
    var code: u16 = 200;
    var payload: []u8 = undefined;
    store.lock.lock();
    defer store.lock.unlock();
    if (std.mem.eql(u8, path, "/api/rooms")) {
        payload = try alloc.dupe(u8, "{\"rooms\":[\"Lobby\",\"Thirtysomething\",\"Computer Help\",\"Sports Bar\",\"New Member Lounge\"]}");
    } else if (std.mem.eql(u8, path, "/api/signup") or std.mem.eql(u8, path, "/api/login")) {
        const name = try field(body, "screenName", alloc);
        const password = try field(body, "password", alloc);
        defer alloc.free(name);
        defer alloc.free(password);
        if (std.mem.eql(u8, path, "/api/signup")) {
            if (!validName(name)) {
                code = 400;
                payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Screen names are 3 to 16 letters and numbers, starting with a letter.\"}");
            } else if (password.len < 4) {
                code = 400;
                payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Password needs at least 4 characters.\"}");
            } else if (findUser(store, name) != null) {
                code = 409;
                payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"That screen name is taken.\"}");
            } else {
                var salt_raw: [16]u8 = undefined;
                std.crypto.random.bytes(&salt_raw);
                const salt = try hexAlloc(alloc, &salt_raw);
                const digest = hex32(hashPassword(password, salt));
                const id = store.next_user;
                store.next_user += 1;
                try store.users.append(.{ .id = id, .name = try alloc.dupe(u8, name), .salt = salt, .hash = try alloc.dupe(u8, &digest), .created = std.time.timestamp() });
                try store.mail.append(.{ .id = store.next_mail, .from_id = id, .to_id = id, .subject = try alloc.dupe(u8, "Welcome"), .body = try alloc.dupe(u8, "You have a screen name. The lobby is open. This server is the only host."), .unread = true, .created = std.time.timestamp() });
                store.next_mail += 1;
                var token_raw: [24]u8 = undefined;
                std.crypto.random.bytes(&token_raw);
                const token = try hexAlloc(alloc, &token_raw);
                try store.sessions.append(.{ .token = try alloc.dupe(u8, token), .user_id = id, .seen = std.time.timestamp() });
                try store.save();
                payload = try std.fmt.allocPrint(alloc, "{{\"ok\":true,\"token\":\"{s}\",\"screenName\":{s}}}", .{ token, try jsonString(alloc, name) });
            }
        } else if (findUser(store, name)) |idx| {
            const user = store.users.items[idx];
            const digest = hex32(hashPassword(password, user.salt));
            if (!std.mem.eql(u8, user.hash, &digest)) {
                code = 401;
                payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Password does not match.\"}");
            } else {
                var token_raw: [24]u8 = undefined;
                std.crypto.random.bytes(&token_raw);
                const token = try hexAlloc(alloc, &token_raw);
                try store.sessions.append(.{ .token = try alloc.dupe(u8, token), .user_id = user.id, .seen = std.time.timestamp() });
                try store.save();
                payload = try std.fmt.allocPrint(alloc, "{{\"ok\":true,\"token\":\"{s}\",\"screenName\":{s}}}", .{ token, try jsonString(alloc, user.name) });
            }
        } else {
            code = 401;
            payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"That screen name is not on this server.\"}");
        }
    } else if (auth(store, auth_header)) |user| {
        if (std.mem.startsWith(u8, path, "/api/messages") and std.mem.eql(u8, method, "GET")) {
            const room = queryRoom(path);
            const since = querySince(path);
            var out = std.ArrayList(u8).init(alloc);
            try out.appendSlice("{\"messages\":[");
            var first = true;
            for (store.messages.items) |m| {
                if (!std.mem.eql(u8, m.room, room) or m.id <= since) continue;
                const sender = userById(store, m.user_id) orelse continue;
                if (!first) try out.append(',');
                first = false;
                try out.writer().print("{{\"id\":{d},\"name\":{s},\"body\":{s},\"created\":{d}}}", .{ m.id, try jsonString(alloc, sender.name), try jsonString(alloc, m.body), m.created });
            }
            try out.appendSlice("],\"online\":[");
            var seen_first = true;
            const now = std.time.timestamp();
            for (store.sessions.items) |s| {
                if (now - s.seen > 90) continue;
                const who = userById(store, s.user_id) orelse continue;
                if (!seen_first) try out.append(',');
                seen_first = false;
                try out.appendSlice(try jsonString(alloc, who.name));
            }
            var unread: u32 = 0;
            for (store.mail.items) |m| if (m.to_id == user.id and m.unread) {
                unread += 1;
            };
            try out.writer().print("],\"unread\":{d}}}", .{unread});
            payload = try out.toOwnedSlice();
        } else if (std.mem.eql(u8, path, "/api/messages")) {
            const room = try field(body, "room", alloc);
            const text = try field(body, "text", alloc);
            var known = false;
            for (rooms) |r| if (std.mem.eql(u8, r, room)) {
                known = true;
            };
            if (!known or text.len == 0) {
                code = 400;
                payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Say something in a real room.\"}");
            } else {
                const id = store.next_msg;
                store.next_msg += 1;
                try store.messages.append(.{ .id = id, .room = try alloc.dupe(u8, room), .user_id = user.id, .body = try alloc.dupe(u8, text[0..@min(text.len, 240)]), .created = std.time.timestamp() });
                try store.save();
                payload = try std.fmt.allocPrint(alloc, "{{\"ok\":true,\"id\":{d}}}", .{id});
            }
        } else if (std.mem.eql(u8, path, "/api/mail") and std.mem.eql(u8, method, "GET")) {
            var out = std.ArrayList(u8).init(alloc);
            try out.appendSlice("{\"mail\":[");
            var first = true;
            var i: usize = store.mail.items.len;
            while (i > 0) {
                i -= 1;
                const m = store.mail.items[i];
                if (m.to_id != user.id) continue;
                const sender = userById(store, m.from_id) orelse continue;
                if (!first) try out.append(',');
                first = false;
                try out.writer().print("{{\"id\":{d},\"sender\":{s},\"subject\":{s},\"body\":{s},\"unread\":{s}}}", .{ m.id, try jsonString(alloc, sender.name), try jsonString(alloc, m.subject), try jsonString(alloc, m.body), if (m.unread) "true" else "false" });
                store.mail.items[i].unread = false;
            }
            try out.appendSlice("]}");
            try store.save();
            payload = try out.toOwnedSlice();
        } else if (std.mem.eql(u8, path, "/api/mail")) {
            const to_name = try field(body, "to", alloc);
            const subject = try field(body, "subject", alloc);
            const text = try field(body, "body", alloc);
            if (findUser(store, to_name)) |idx| {
                try store.mail.append(.{ .id = store.next_mail, .from_id = user.id, .to_id = store.users.items[idx].id, .subject = try alloc.dupe(u8, if (subject.len == 0) "(no subject)" else subject), .body = try alloc.dupe(u8, text), .unread = true, .created = std.time.timestamp() });
                store.next_mail += 1;
                try store.save();
                payload = try alloc.dupe(u8, "{\"ok\":true}");
            } else {
                code = 404;
                payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"No member by that screen name.\"}");
            }
        } else {
            code = 404;
            payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Not found.\"}");
        }
    } else if (std.mem.startsWith(u8, path, "/api/")) {
        code = 401;
        payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Sign on first.\"}");
    } else {
        code = 404;
        payload = try alloc.dupe(u8, "{\"ok\":false,\"error\":\"Not found.\"}");
    }
    return std.fmt.allocPrint(alloc, "HTTP/1.1 {d} OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ code, payload.len, payload });
}

fn queryRoom(path: []const u8) []const u8 {
    const key = "room=";
    const at = std.mem.indexOf(u8, path, key) orelse return "Lobby";
    const rest = path[at + key.len ..];
    const end = std.mem.indexOfScalar(u8, rest, '&') orelse rest.len;
    const raw = rest[0..end];
    if (std.mem.eql(u8, raw, "Computer+Help") or std.mem.eql(u8, raw, "Computer%20Help")) return "Computer Help";
    if (std.mem.eql(u8, raw, "Sports+Bar") or std.mem.eql(u8, raw, "Sports%20Bar")) return "Sports Bar";
    if (std.mem.eql(u8, raw, "New+Member+Lounge") or std.mem.eql(u8, raw, "New%20Member%20Lounge")) return "New Member Lounge";
    for (rooms) |r| if (std.mem.eql(u8, r, raw)) return r;
    return "Lobby";
}

fn querySince(path: []const u8) u32 {
    const key = "since=";
    const at = std.mem.indexOf(u8, path, key) orelse return 0;
    const rest = path[at + key.len ..];
    const end = std.mem.indexOfScalar(u8, rest, '&') orelse rest.len;
    return std.fmt.parseInt(u32, rest[0..end], 10) catch 0;
}

fn serveClient(store: *Store, conn: std.net.Server.Connection) void {
    defer conn.stream.close();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var buf: [16384]u8 = undefined;
    const n = conn.stream.read(&buf) catch return;
    const req = buf[0..n];
    const line_end = std.mem.indexOf(u8, req, "\r\n") orelse return;
    var line = std.mem.splitScalar(u8, req[0..line_end], ' ');
    const method = line.next() orelse return;
    const target = line.next() orelse return;
    const header_end = std.mem.indexOf(u8, req, "\r\n\r\n") orelse return;
    const headers = req[0 .. header_end + 2];
    const body = req[header_end + 4 ..];
    if (std.mem.eql(u8, method, "OPTIONS")) {
        _ = conn.stream.writeAll("HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\nContent-Length: 0\r\nConnection: close\r\n\r\n") catch return;
        return;
    }
    const response = handle(store, alloc, method, target, headers, body) catch return;
    _ = conn.stream.writeAll(response) catch return;
}

fn selftest() !void {
    var store = Store.init(std.heap.page_allocator, "aol-selftest.db");
    const signup = try handle(&store, std.heap.page_allocator, "POST", "/api/signup", "", "{\"screenName\":\"ModemQueen\",\"password\":\"dialup\"}");
    if (std.mem.indexOf(u8, signup, "\"ok\":true") == null) return error.SignupFailed;
    const token_at = std.mem.indexOf(u8, signup, "\"token\":\"") orelse return error.NoToken;
    const token = signup[token_at + 9 .. token_at + 9 + 48];
    var auth_buf: [80]u8 = undefined;
    const header = try std.fmt.bufPrint(&auth_buf, "Authorization: Bearer {s}", .{token});
    const posted = try handle(&store, std.heap.page_allocator, "POST", "/api/messages", header, "{\"room\":\"Lobby\",\"text\":\"wb from the kitchen phone\"}");
    if (std.mem.indexOf(u8, posted, "\"ok\":true") == null) return error.PostFailed;
    const listed = try handle(&store, std.heap.page_allocator, "GET", "/api/messages?room=Lobby&since=0", header, "");
    if (std.mem.indexOf(u8, listed, "kitchen phone") == null) return error.MissingChat;
    _ = try handle(&store, std.heap.page_allocator, "POST", "/api/signup", "", "{\"screenName\":\"CoolDude95\",\"password\":\"lobby\"}");
    const mailed = try handle(&store, std.heap.page_allocator, "POST", "/api/mail", header, "{\"to\":\"CoolDude95\",\"subject\":\"tonight\",\"body\":\"lobby after dinner\"}");
    if (std.mem.indexOf(u8, mailed, "\"ok\":true") == null) return error.MailFailed;
    std.debug.print("SELF-TEST OK\n", .{});
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    if (args.next()) |arg| if (std.mem.eql(u8, arg, "--selftest")) return selftest();
    var store = Store.init(std.heap.page_allocator, "aol.db");
    try store.load();
    pool.pool = pool.Pool.init(std.heap.page_allocator);
    const pool_thread = try std.Thread.spawn(.{}, pool.start, .{});
    pool_thread.detach();
    const addr = try std.net.Address.parseIp4("0.0.0.0", 8080);
    var server = try addr.listen(.{ .reuse_address = true });
    std.debug.print("America Online server on http://0.0.0.0:8080\nDatabase: aol.db\n", .{});
    while (true) {
        const conn = server.accept() catch continue;
        const thread = try std.Thread.spawn(.{}, serveClient, .{ &store, conn });
        thread.detach();
    }
}
