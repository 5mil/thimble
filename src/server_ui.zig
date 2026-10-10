const std = @import("std");
const WINAPI = std.os.windows.WINAPI;
const HWND = *opaque {};
const HINSTANCE = *opaque {};
const HBRUSH = *opaque {};
const LRESULT = isize;
const WPARAM = usize;
const LPARAM = isize;
const WNDCLASSA = extern struct {
    style: u32 = 0,
    lpfnWndProc: *const fn (HWND, u32, WPARAM, LPARAM) callconv(WINAPI) LRESULT,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?*opaque {} = null,
    hCursor: ?*opaque {} = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?[*:0]const u8 = null,
    lpszClassName: [*:0]const u8,
};
const MSG = extern struct { hwnd: ?HWND, message: u32, wParam: WPARAM, lParam: LPARAM, time: u32, pt: extern struct { x: i32, y: i32 } };
extern "user32" fn RegisterClassA(wnd: *const WNDCLASSA) callconv(WINAPI) u16;
extern "user32" fn CreateWindowExA(ex: u32, class: [*:0]const u8, title: [*:0]const u8, style: u32, x: i32, y: i32, w: i32, h: i32, parent: ?HWND, menu: ?*opaque {}, inst: HINSTANCE, param: ?*anyopaque) callconv(WINAPI) ?HWND;
extern "user32" fn ShowWindow(hwnd: HWND, cmd: i32) callconv(WINAPI) i32;
extern "user32" fn GetMessageA(msg: *MSG, hwnd: ?HWND, min: u32, max: u32) callconv(WINAPI) i32;
extern "user32" fn TranslateMessage(msg: *const MSG) callconv(WINAPI) i32;
extern "user32" fn DispatchMessageA(msg: *const MSG) callconv(WINAPI) LRESULT;
extern "user32" fn DefWindowProcA(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT;
extern "user32" fn PostQuitMessage(code: i32) callconv(WINAPI) void;
extern "user32" fn SetWindowTextA(hwnd: HWND, text: [*:0]const u8) callconv(WINAPI) i32;
extern "user32" fn GetWindowTextA(hwnd: HWND, buf: [*]u8, max: i32) callconv(WINAPI) i32;
extern "user32" fn SendMessageA(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT;
extern "user32" fn SetFocus(hwnd: HWND) callconv(WINAPI) HWND;
extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(WINAPI) HINSTANCE;
extern "gdi32" fn CreateSolidBrush(color: u32) callconv(WINAPI) HBRUSH;

const WS_OVERLAPPEDWINDOW: u32 = 0x00CF0000;
const WS_CHILD: u32 = 0x40000000;
const WS_VISIBLE: u32 = 0x10000000;
const WS_BORDER: u32 = 0x00800000;
const WS_VSCROLL: u32 = 0x00200000;
const ES_AUTOHSCROLL: u32 = 0x0080;
const CBS_DROPDOWNLIST: u32 = 0x0003;
const BS_AUTOCHECKBOX: u32 = 0x0003;
const CB_ADDSTRING: u32 = 0x0143;
const CB_RESETCONTENT: u32 = 0x014B;
const CB_SETCURSEL: u32 = 0x014E;
const CB_GETCURSEL: u32 = 0x0147;
const LB_ADDSTRING: u32 = 0x0180;
const LB_RESETCONTENT: u32 = 0x0184;
const LB_GETCURSEL: u32 = 0x0188;
const BM_GETCHECK: u32 = 0x00F0;
const CBN_SELCHANGE: u32 = 1;
const WM_DESTROY: u32 = 2;
const WM_COMMAND: u32 = 0x0111;

const Coin = struct { name: [:0]const u8, algo: [:0]const u8, port: u16, note: [:0]const u8, merges: []const [:0]const u8 };
const coins = [_]Coin{
    .{ .name = "Bitcoin", .algo = "sha256d", .port = 3333, .note = "ASIC. Port 3333. Difficulty starts low.", .merges = &.{ "Namecoin", "Elastos" } },
    .{ .name = "Litecoin", .algo = "scrypt", .port = 3334, .note = "Scrypt ASIC or GPU. Port 3334.", .merges = &.{ "Dogecoin" } },
    .{ .name = "Monero", .algo = "randomx", .port = 3337, .note = "CPU. Port 3337. No usual merge.", .merges = &.{ "none" } },
    .{ .name = "Ethereum Classic", .algo = "ethash", .port = 3335, .note = "GPU. Port 3335.", .merges = &.{ "none" } },
    .{ .name = "Ravencoin", .algo = "kawpow", .port = 3336, .note = "GPU. Port 3336.", .merges = &.{ "none" } },
    .{ .name = "Dogecoin", .algo = "scrypt", .port = 3334, .note = "Usually merged under Litecoin.", .merges = &.{ "Litecoin" } },
    .{ .name = "Yescrypt", .algo = "yescrypt", .port = 3338, .note = "CPU. Port 3338.", .merges = &.{ "none" } },
};

const Module = struct { name: [32]u8, name_len: usize, algo: [16]u8, algo_len: usize, port: u16, on: bool, merge: [24]u8, merge_len: usize, bonus: u8 };
var modules: [8]Module = undefined;
var module_count: usize = 0;
var house_on = false;
var keep_all = true;

var repo_box: HWND = undefined;
var coin_box: HWND = undefined;
var merge_box: HWND = undefined;
var merge_check: HWND = undefined;
var bonus_box: HWND = undefined;
var data_box: HWND = undefined;
var house_check: HWND = undefined;
var list_box: HWND = undefined;
var report_box: HWND = undefined;
var log_box: HWND = undefined;
var brush: HBRUSH = undefined;

fn child(parent: HWND, class: [*:0]const u8, title: [*:0]const u8, style: u32, x: i32, y: i32, w: i32, h: i32, id: usize) HWND {
    return CreateWindowExA(0, class, title, style, x, y, w, h, parent, @ptrFromInt(id), GetModuleHandleA(null), null).?;
}

fn note(text: []const u8) void {
    var z: [280]u8 = undefined;
    const n = @min(text.len, z.len - 1);
    @memcpy(z[0..n], text[0..n]);
    z[n] = 0;
    _ = SetWindowTextA(log_box, z[0..n :0]);
}

fn textOf(control: HWND, buf: []u8) []u8 {
    const n = GetWindowTextA(control, buf.ptr, @intCast(buf.len));
    return buf[0..@intCast(n)];
}

fn fillMerge(index: isize) void {
    _ = SendMessageA(merge_box, CB_RESETCONTENT, 0, 0);
    if (index < 0 or index >= coins.len) return;
    for (coins[@intCast(index)].merges) |name| {
        _ = SendMessageA(merge_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(name.ptr)));
    }
    _ = SendMessageA(merge_box, CB_SETCURSEL, 0, 0);
}

fn paintModules() void {
    _ = SendMessageA(list_box, LB_RESETCONTENT, 0, 0);
    for (modules[0..module_count]) |m| {
        var line: [96]u8 = undefined;
        const text = std.fmt.bufPrintZ(&line, "{s}  {s}:{d}  {s}  merge {s}  bonus {d}%", .{ m.name[0..m.name_len], m.algo[0..m.algo_len], m.port, if (m.on) "on" else "off", m.merge[0..m.merge_len], m.bonus }) catch continue;
        _ = SendMessageA(list_box, LB_ADDSTRING, 0, @bitCast(@intFromPtr(text.ptr)));
    }
}

fn saveModules() void {
    var file = std.fs.cwd().createFile("pools.cfg", .{}) catch return;
    defer file.close();
    for (modules[0..module_count]) |m| {
        file.writer().print("{s}\t{s}\t{d}\t{s}\t{s}\t{d}\n", .{ m.name[0..m.name_len], m.algo[0..m.algo_len], m.port, if (m.on) "1" else "0", m.merge[0..m.merge_len], m.bonus }) catch return;
    }
    file.writer().print("house\t{s}\ndata\t{s}\n", .{ if (house_on) "1" else "0", if (keep_all) "all" else "totals" }) catch return;
}

fn addModule(parent: HWND) void {
    if (module_count >= modules.len) return note("Eight modules is the room.");
    const picked = SendMessageA(coin_box, CB_GETCURSEL, 0, 0);
    if (picked < 0) return note("Pick a coin, or type a repo.");
    const coin = coins[@intCast(picked)];
    var repo: [160]u8 = undefined;
    const typed = textOf(repo_box, &repo);
    var m = &modules[module_count];
    const n = @min(coin.name.len, m.name.len);
    @memcpy(m.name[0..n], coin.name[0..n]);
    m.name_len = n;
    const a = @min(coin.algo.len, m.algo.len);
    @memcpy(m.algo[0..a], coin.algo[0..a]);
    m.algo_len = a;
    m.port = coin.port;
    m.on = true;
    const merge_on = SendMessageA(merge_check, BM_GETCHECK, 0, 0) == 1;
    if (merge_on) {
        var merge: [24]u8 = undefined;
        const mt = textOf(merge_box, &merge);
        const ml = @min(mt.len, m.merge.len);
        @memcpy(m.merge[0..ml], mt[0..ml]);
        m.merge_len = ml;
    } else {
        @memcpy(m.merge[0..4], "none");
        m.merge_len = 4;
    }
    const bonus_i = SendMessageA(bonus_box, CB_GETCURSEL, 0, 0);
    m.bonus = switch (bonus_i) {
        1 => 5,
        2 => 10,
        else => 0,
    };
    house_on = SendMessageA(house_check, BM_GETCHECK, 0, 0) == 1;
    keep_all = SendMessageA(data_box, CB_GETCURSEL, 0, 0) != 1;
    module_count += 1;
    saveModules();
    paintModules();
    if (typed.len > 8 and std.mem.startsWith(u8, typed, "https://")) {
        note("Module added. Repo stays in the box for Fetch coin.");
    } else note("Module added. Toggle it in the list. Concurrent modules stay on together.");
    _ = parent;
}

fn toggleModule() void {
    const i = SendMessageA(list_box, LB_GETCURSEL, 0, 0);
    if (i < 0 or i >= module_count) return note("Select a module first.");
    modules[@intCast(i)].on = !modules[@intCast(i)].on;
    saveModules();
    paintModules();
    note(if (modules[@intCast(i)].on) "That pool is on." else "That pool is off. The others keep running.");
}

fn showReport() void {
    const text = @import("pool.zig").reportText(std.heap.page_allocator) catch return note("report failed");
    _ = SendMessageA(report_box, LB_RESETCONTENT, 0, 0);
    var held: [24][160]u8 = undefined;
    var nline: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (line.len == 0 or nline >= held.len) continue;
        const n = @min(line.len, held[nline].len - 1);
        @memcpy(held[nline][0..n], line[0..n]);
        held[nline][n] = 0;
        _ = SendMessageA(report_box, LB_ADDSTRING, 0, @bitCast(@intFromPtr(&held[nline])));
        nline += 1;
    }
    note("Report is live. Shares, workers, blocks, and the line.");
}
    var repo: [180]u8 = undefined;
    const typed = textOf(repo_box, &repo);
    if (!std.mem.startsWith(u8, typed, "https://github.com/") and !std.mem.startsWith(u8, typed, "https://gitlab.com/")) {
        return note("The box takes https://github.com/ or https://gitlab.com/.");
    }
    const name = std.fs.path.stem(typed);
    var dest_buf: [200]u8 = undefined;
    const dest = std.fmt.bufPrint(&dest_buf, "coin-src/{s}", .{name}) catch return;
    var proc = std.process.Child.init(&.{ "git", "clone", "--depth", "1", typed, dest }, std.heap.page_allocator);
    const term = proc.spawnAndWait() catch return note("git did not start");
    if (term == .Exited and term.Exited == 0) {
        var file = std.fs.cwd().createFile("coin.cfg", .{}) catch return;
        defer file.close();
        file.writer().print("name={s}\nrepo={s}\npath={s}\n", .{ name, typed, dest }) catch {};
        note("Cloned. The pool advertises that coin.");
    } else note("Clone failed. The box is editable if the address is wrong.");
}

fn wnd(window: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    switch (msg) {
        1 => {
            _ = child(window, "STATIC", "AMERICA  Online  —  the host", WS_CHILD | WS_VISIBLE, 16, 10, 360, 20, 1);
            _ = child(window, "STATIC", "The rooms are counting. Type the repo. Backspace works.", WS_CHILD | WS_VISIBLE, 16, 32, 520, 16, 2);
            repo_box = child(window, "EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, 16, 54, 430, 22, 5);
            _ = child(window, "BUTTON", "Fetch coin", WS_CHILD | WS_VISIBLE, 454, 52, 110, 26, 6);
            _ = child(window, "STATIC", "Or pick a coin", WS_CHILD | WS_VISIBLE, 16, 84, 120, 16, 9);
            coin_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 140, 80, 180, 160, 10);
            for (coins) |c| _ = SendMessageA(coin_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(c.name.ptr)));
            _ = SendMessageA(coin_box, CB_SETCURSEL, 0, 0);
            merge_check = child(window, "BUTTON", "Merge mine", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, 340, 82, 110, 20, 11);
            merge_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 454, 80, 110, 120, 12);
            fillMerge(0);
            _ = child(window, "STATIC", "Bonus to distribute", WS_CHILD | WS_VISIBLE, 16, 112, 130, 16, 13);
            bonus_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 150, 108, 120, 100, 14);
            inline for ([_][:0]const u8{ "none", "5% house", "10% house" }) |b| _ = SendMessageA(bonus_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(b.ptr)));
            _ = SendMessageA(bonus_box, CB_SETCURSEL, 0, 0);
            _ = child(window, "STATIC", "Share data", WS_CHILD | WS_VISIBLE, 284, 112, 80, 16, 15);
            data_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 364, 108, 120, 80, 16);
            inline for ([_][:0]const u8{ "keep all", "totals only" }) |b| _ = SendMessageA(data_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(b.ptr)));
            _ = SendMessageA(data_box, CB_SETCURSEL, 0, 0);
            house_check = child(window, "BUTTON", "Mine to this pool (house rig)", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, 16, 138, 220, 20, 17);
            _ = child(window, "BUTTON", "Add module", WS_CHILD | WS_VISIBLE, 250, 134, 110, 26, 18);
            _ = child(window, "BUTTON", "Toggle selected", WS_CHILD | WS_VISIBLE, 368, 134, 120, 26, 19);
            _ = child(window, "BUTTON", "Report", WS_CHILD | WS_VISIBLE, 496, 134, 68, 26, 21);
            list_box = child(window, "LISTBOX", "", WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL, 16, 168, 548, 70, 20);
            report_box = child(window, "LISTBOX", "", WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL, 16, 244, 548, 90, 22);
            log_box = child(window, "STATIC", "Recommended: Bitcoin on 3333. Litecoin merges Dogecoin. House shares become the bonus.", WS_CHILD | WS_VISIBLE | WS_BORDER, 16, 286, 548, 36, 4);
            _ = SetFocus(repo_box);
            return 0;
        },
        WM_COMMAND => {
            const id = wp & 0xffff;
            const code = wp >> 16;
            if (id == 10 and code == CBN_SELCHANGE) {
                fillMerge(SendMessageA(coin_box, CB_GETCURSEL, 0, 0));
                const i = SendMessageA(coin_box, CB_GETCURSEL, 0, 0);
                if (i >= 0) note(coins[@intCast(i)].note);
            }
            if (id == 6) fetchRepo();
            if (id == 18) addModule(window);
            if (id == 19) toggleModule();
            if (id == 21) showReport();
            return 0;
        },
        WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return DefWindowProcA(window, msg, wp, lp);
}

pub fn open() void {
    brush = CreateSolidBrush(0x00181012);
    const inst = GetModuleHandleA(null);
    const class = WNDCLASSA{
        .lpfnWndProc = wnd,
        .hInstance = inst,
        .hbrBackground = brush,
        .lpszClassName = "AmericaOnlineHost",
    };
    _ = RegisterClassA(&class);
    const window = CreateWindowExA(0, "AmericaOnlineHost", "America Online — Host", WS_OVERLAPPEDWINDOW, 80, 40, 600, 390, null, null, inst, null).?;
    _ = ShowWindow(window, 5);
    var message: MSG = undefined;
    while (GetMessageA(&message, null, 0, 0) != 0) {
        _ = TranslateMessage(&message);
        _ = DispatchMessageA(&message);
    }
}
