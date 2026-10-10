const std = @import("std");
const WINAPI = std.os.windows.WINAPI;
const HWND = *opaque {};
const HINSTANCE = *opaque {};
const HMENU = *opaque {};
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
extern "user32" fn CreateWindowExA(ex: u32, class: [*:0]const u8, title: [*:0]const u8, style: u32, x: i32, y: i32, w: i32, h: i32, parent: ?HWND, menu: ?HMENU, inst: HINSTANCE, param: ?*anyopaque) callconv(WINAPI) ?HWND;
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
extern "user32" fn CreateMenu() callconv(WINAPI) HMENU;
extern "user32" fn CreatePopupMenu() callconv(WINAPI) HMENU;
extern "user32" fn AppendMenuA(menu: HMENU, flags: u32, id: usize, text: [*:0]const u8) callconv(WINAPI) i32;
extern "user32" fn SetMenu(hwnd: HWND, menu: HMENU) callconv(WINAPI) i32;
extern "user32" fn SetTimer(hwnd: HWND, id: usize, ms: u32, proc: ?*anyopaque) callconv(WINAPI) usize;
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
const MF_STRING: u32 = 0;
const MF_POPUP: u32 = 0x10;
const CB_ADDSTRING: u32 = 0x0143;
const CB_RESETCONTENT: u32 = 0x014B;
const CB_SETCURSEL: u32 = 0x014E;
const CB_GETCURSEL: u32 = 0x0147;
const LB_ADDSTRING: u32 = 0x0180;
const LB_RESETCONTENT: u32 = 0x0184;
const LB_GETCURSEL: u32 = 0x0188;
const BM_GETCHECK: u32 = 0x00F0;
const BM_SETCHECK: u32 = 0x00F1;
const CBN_SELCHANGE: u32 = 1;
const WM_DESTROY: u32 = 2;
const WM_COMMAND: u32 = 0x0111;
const WM_TIMER: u32 = 0x0113;
const ID_SETTINGS: usize = 101;
const ID_REFRESH: usize = 102;
const ID_EXIT: usize = 103;

const Coin = struct { name: [:0]const u8, algo: [:0]const u8, port: u16, note: [:0]const u8, merges: []const [:0]const u8 };
const coins = [_]Coin{
    .{ .name = "Bitcoin", .algo = "sha256d", .port = 3333, .note = "ASIC. Port 3333.", .merges = &.{ "Namecoin", "Elastos" } },
    .{ .name = "Litecoin", .algo = "scrypt", .port = 3334, .note = "Scrypt. Port 3334. Merges Dogecoin.", .merges = &.{ "Dogecoin" } },
    .{ .name = "Monero", .algo = "randomx", .port = 3337, .note = "CPU. Port 3337.", .merges = &.{ "none" } },
    .{ .name = "Ethereum Classic", .algo = "ethash", .port = 3335, .note = "GPU. Port 3335.", .merges = &.{ "none" } },
    .{ .name = "Ravencoin", .algo = "kawpow", .port = 3336, .note = "GPU. Port 3336.", .merges = &.{ "none" } },
    .{ .name = "Dogecoin", .algo = "scrypt", .port = 3334, .note = "Usually under Litecoin.", .merges = &.{ "Litecoin" } },
    .{ .name = "Yescrypt", .algo = "yescrypt", .port = 3338, .note = "CPU. Port 3338.", .merges = &.{ "none" } },
};

const Module = struct { name: [32]u8, name_len: usize, algo: [16]u8, algo_len: usize, port: u16, on: bool, merge: [24]u8, merge_len: usize, bonus: u8, source: [96]u8, source_len: usize, wallet: [64]u8, wallet_len: usize };
var modules: [8]Module = undefined;
var module_count: usize = 0;
var house_on = false;
var keep_all = true;
var configured = false;

var main_hwnd: HWND = undefined;
var settings_hwnd: ?HWND = null;
var repo_box: HWND = undefined;
var coin_box: HWND = undefined;
var merge_box: HWND = undefined;
var merge_check: HWND = undefined;
var bonus_box: HWND = undefined;
var data_box: HWND = undefined;
var house_check: HWND = undefined;
var source_box: HWND = undefined;
var wallet_box: HWND = undefined;
var settings_list: HWND = undefined;
var report_box: HWND = undefined;
var summary: HWND = undefined;
var brush: HBRUSH = undefined;

fn child(parent: HWND, class: [*:0]const u8, title: [*:0]const u8, style: u32, x: i32, y: i32, w: i32, h: i32, id: usize) HWND {
    return CreateWindowExA(0, class, title, style, x, y, w, h, parent, @ptrFromInt(id), GetModuleHandleA(null), null).?;
}
fn textOf(control: HWND, buf: []u8) []u8 {
    const n = GetWindowTextA(control, buf.ptr, @intCast(buf.len));
    return buf[0..@intCast(n)];
}
fn setText(control: HWND, text: []const u8) void {
    var z: [240]u8 = undefined;
    const n = @min(text.len, z.len - 1);
    @memcpy(z[0..n], text[0..n]);
    z[n] = 0;
    _ = SetWindowTextA(control, z[0..n :0]);
}

fn copyInto(dst: []u8, src: []const u8) usize {
    const n = @min(dst.len, src.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

fn saveModules() void {
    var file = std.fs.cwd().createFile("pools.cfg", .{}) catch return;
    defer file.close();
    for (modules[0..module_count]) |m| {
        file.writer().print("{s}\t{s}\t{d}\t{s}\t{s}\t{d}\t{s}\t{s}\n", .{ m.name[0..m.name_len], m.algo[0..m.algo_len], m.port, if (m.on) "1" else "0", m.merge[0..m.merge_len], m.bonus, m.source[0..m.source_len], m.wallet[0..m.wallet_len] }) catch return;
    }
    file.writer().print("#house\t{s}\n#data\t{s}\n", .{ if (house_on) "1" else "0", if (keep_all) "all" else "totals" }) catch return;
    configured = module_count > 0;
}

fn loadModules() void {
    const raw = std.fs.cwd().readFileAlloc(std.heap.page_allocator, "pools.cfg", 1 << 16) catch return;
    var it = std.mem.splitScalar(u8, raw, '\n');
    while (it.next()) |line| {
        if (line.len < 2) continue;
        if (line.len < 2 or line[0] == '#') {
            if (std.mem.indexOf(u8, line, "house") != null) house_on = std.mem.indexOf(u8, line, "1") != null;
            if (std.mem.indexOf(u8, line, "data") != null) keep_all = std.mem.indexOf(u8, line, "totals") == null;
            continue;
        }
        if (std.mem.startsWith(u8, line, "house") or std.mem.startsWith(u8, line, "data")) continue;
        if (module_count >= modules.len) continue;
        var parts = std.mem.splitScalar(u8, line, '\t');
        const name = parts.next() orelse continue;
        const algo = parts.next() orelse continue;
        const port = std.fmt.parseInt(u16, parts.next() orelse "3333", 10) catch 3333;
        const on = std.mem.eql(u8, parts.next() orelse "1", "1");
        const merge = parts.next() orelse "none";
        const bonus = std.fmt.parseInt(u8, parts.next() orelse "0", 10) catch 0;
        var m = &modules[module_count];
        m.name_len = copyInto(&m.name, name);
        m.algo_len = copyInto(&m.algo, algo);
        m.port = port;
        m.on = on;
        m.merge_len = copyInto(&m.merge, merge);
        m.bonus = bonus;
        m.source_len = copyInto(&m.source, parts.next() orelse "");
        m.wallet_len = copyInto(&m.wallet, parts.next() orelse "");
        var twin = false;
        for (modules[0..module_count]) |*old| {
            if (old.port == m.port and std.mem.eql(u8, old.name[0..old.name_len], m.name[0..m.name_len])) {
                if (m.source_len > 0) old.* = m.*;
                twin = true;
                break;
            }
        }
        if (!twin) module_count += 1;
    }
    configured = module_count > 0;
}

fn fillMerge(index: isize) void {
    _ = SendMessageA(merge_box, CB_RESETCONTENT, 0, 0);
    if (index < 0 or index >= coins.len) return;
    for (coins[@intCast(index)].merges) |name| {
        _ = SendMessageA(merge_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(name.ptr)));
    }
    _ = SendMessageA(merge_box, CB_SETCURSEL, 0, 0);
}

fn paintSettingsList() void {
    _ = SendMessageA(settings_list, LB_RESETCONTENT, 0, 0);
    for (modules[0..module_count]) |m| {
        var line: [96]u8 = undefined;
        const text = std.fmt.bufPrintZ(&line, "{s}  {s}:{d}  {s}  {s}", .{ m.name[0..m.name_len], m.algo[0..m.algo_len], m.port, if (m.on) "running" else "stopped", if (m.source_len == 0) "no source" else m.source[0..m.source_len] }) catch continue;
        _ = SendMessageA(settings_list, LB_ADDSTRING, 0, @bitCast(@intFromPtr(text.ptr)));
    }
}

fn showReport() void {
    const text = @import("pool.zig").reportText(std.heap.page_allocator) catch return;
    _ = SendMessageA(report_box, LB_RESETCONTENT, 0, 0);
    var head: [240]u8 = undefined;
    const head_s = @import("modules.zig").sentence(&head);
    setText(summary, head_s);
    var held: [24][180]u8 = undefined;
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
}

fn addModule() void {
    const picked = SendMessageA(coin_box, CB_GETCURSEL, 0, 0);
    if (picked < 0) return;
    const coin = coins[@intCast(picked)];
    var m: *Module = undefined;
    var existing = false;
    for (modules[0..module_count]) |*old| {
        if (old.port == coin.port and std.mem.eql(u8, old.name[0..old.name_len], coin.name)) {
            m = old;
            existing = true;
            break;
        }
    }
    if (!existing) {
        if (module_count >= modules.len) return setText(summary, "Eight modules is the room.");
        m = &modules[module_count];
        module_count += 1;
    }
    m.name_len = copyInto(&m.name, coin.name);
    m.algo_len = copyInto(&m.algo, coin.algo);
    m.port = coin.port;
    m.on = true;
    if (SendMessageA(merge_check, BM_GETCHECK, 0, 0) == 1) {
        var merge: [24]u8 = undefined;
        m.merge_len = copyInto(&m.merge, textOf(merge_box, &merge));
    } else m.merge_len = copyInto(&m.merge, "none");
    m.bonus = switch (SendMessageA(bonus_box, CB_GETCURSEL, 0, 0)) {
        1 => 5,
        2 => 10,
        else => 0,
    };
    house_on = SendMessageA(house_check, BM_GETCHECK, 0, 0) == 1;
    var src: [96]u8 = undefined;
    var wal: [64]u8 = undefined;
    m.source_len = copyInto(&m.source, textOf(source_box, &src));
    if (std.mem.startsWith(u8, m.source[0..m.source_len], "https://")) {
        setText(summary, "That is a codebase. Put it in Codebase, not Jobs from.");
    }
    m.wallet_len = copyInto(&m.wallet, textOf(wallet_box, &wal));
    saveModules();
    paintSettingsList();
    showReport();
}

fn toggleModule() void {
    const i = SendMessageA(settings_list, LB_GETCURSEL, 0, 0);
    if (i < 0 or i >= module_count) return;
    modules[@intCast(i)].on = !modules[@intCast(i)].on;
    saveModules();
    paintSettingsList();
    showReport();
}

fn fetchRepo() void {
    var repo: [180]u8 = undefined;
    const typed = textOf(repo_box, &repo);
    if (!std.mem.startsWith(u8, typed, "https://github.com/") and !std.mem.startsWith(u8, typed, "https://gitlab.com/")) {
        return setText(summary, "Repo must be github.com or gitlab.com.");
    }
    const name = std.fs.path.stem(typed);
    var dest_buf: [200]u8 = undefined;
    const dest = std.fmt.bufPrint(&dest_buf, "coin-src/{s}", .{name}) catch return;
    var proc = std.process.Child.init(&.{ "git", "clone", "--depth", "1", typed, dest }, std.heap.page_allocator);
    const term = proc.spawnAndWait() catch return setText(summary, "git did not start");
    if (term == .Exited and term.Exited == 0) {
        var file = std.fs.cwd().createFile("coin.cfg", .{}) catch return;
        defer file.close();
        file.writer().print("name={s}\nrepo={s}\npath={s}\n", .{ name, typed, dest }) catch {};
        setText(summary, "Coin cloned. The pool advertises it.");
    } else setText(summary, "Clone failed.");
}

fn settingsProc(window: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    switch (msg) {
        1 => {
            _ = child(window, "STATIC", "1. Pick a coin.  2. Say where jobs come from.  3. Save.", WS_CHILD | WS_VISIBLE, 12, 8, 500, 16, 1);
            _ = child(window, "STATIC", "Coin", WS_CHILD | WS_VISIBLE, 12, 36, 36, 16, 2);
            coin_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 52, 32, 140, 160, 10);
            for (coins) |c| _ = SendMessageA(coin_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(c.name.ptr)));
            _ = SendMessageA(coin_box, CB_SETCURSEL, 0, 0);
            merge_check = child(window, "BUTTON", "Also merge", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, 204, 34, 90, 20, 11);
            merge_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 298, 32, 110, 120, 12);
            fillMerge(0);
            bonus_box = child(window, "COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 418, 32, 110, 80, 14);
            inline for ([_][:0]const u8{ "no bonus", "5% house", "10% house" }) |b| _ = SendMessageA(bonus_box, CB_ADDSTRING, 0, @bitCast(@intFromPtr(b.ptr)));
            _ = SendMessageA(bonus_box, CB_SETCURSEL, 0, 0);
            _ = child(window, "STATIC", "Jobs from", WS_CHILD | WS_VISIBLE, 12, 68, 64, 16, 21);
            source_box = child(window, "EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, 80, 64, 448, 22, 22);
            _ = child(window, "STATIC", "A pool (pool.example.com:3333) or a node (http://user:pass@127.0.0.1:8332). Not a GitHub link.", WS_CHILD | WS_VISIBLE, 80, 90, 448, 16, 25);
            _ = child(window, "STATIC", "Wallet", WS_CHILD | WS_VISIBLE, 12, 116, 48, 16, 23);
            wallet_box = child(window, "EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, 64, 112, 250, 22, 24);
            house_check = child(window, "BUTTON", "House mines this one", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, 328, 114, 160, 20, 17);
            if (house_on) _ = SendMessageA(house_check, BM_SETCHECK, 1, 0);
            _ = child(window, "BUTTON", "Save", WS_CHILD | WS_VISIBLE, 12, 144, 80, 26, 18);
            _ = child(window, "BUTTON", "Start / stop", WS_CHILD | WS_VISIBLE, 100, 144, 110, 26, 19);
            _ = child(window, "STATIC", "Codebase", WS_CHILD | WS_VISIBLE, 224, 148, 60, 16, 3);
            repo_box = child(window, "EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, 288, 144, 190, 22, 5);
            _ = child(window, "BUTTON", "Fetch", WS_CHILD | WS_VISIBLE, 484, 142, 50, 26, 6);
            settings_list = child(window, "LISTBOX", "", WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL, 12, 180, 520, 128, 20);
            paintSettingsList();
            _ = SetFocus(source_box);
            return 0;
        },
        WM_COMMAND => {
            const id = wp & 0xffff;
            if (id == 10 and (wp >> 16) == CBN_SELCHANGE) fillMerge(SendMessageA(coin_box, CB_GETCURSEL, 0, 0));
            if (id == 6) fetchRepo();
            if (id == 18) addModule();
            if (id == 19) toggleModule();
            return 0;
        },
        WM_DESTROY => {
            settings_hwnd = null;
            return 0;
        },
        else => {},
    }
    return DefWindowProcA(window, msg, wp, lp);
}

fn openSettings() void {
    if (settings_hwnd) |w| {
        _ = ShowWindow(w, 5);
        return;
    }
    const inst = GetModuleHandleA(null);
    const class = WNDCLASSA{ .lpfnWndProc = settingsProc, .hInstance = inst, .hbrBackground = brush, .lpszClassName = "AmericaOnlineSettings" };
    _ = RegisterClassA(&class);
    settings_hwnd = CreateWindowExA(0, "AmericaOnlineSettings", "Pool settings", WS_OVERLAPPEDWINDOW, 80, 60, 560, 360, main_hwnd, null, inst, null);
    if (settings_hwnd) |w| _ = ShowWindow(w, 5);
}

fn mainProc(window: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    switch (msg) {
        1 => {
            _ = child(window, "STATIC", "POOL", WS_CHILD | WS_VISIBLE, 16, 8, 80, 18, 1);
            summary = child(window, "STATIC", "No modules yet.", WS_CHILD | WS_VISIBLE, 16, 28, 700, 18, 2);
            report_box = child(window, "LISTBOX", "", WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL, 16, 52, 740, 380, 22);
            _ = child(window, "STATIC", "Refreshes on its own. Settings is under Pool.", WS_CHILD | WS_VISIBLE, 16, 420, 400, 16, 3);
            _ = SetTimer(window, 1, 4000, null);
            showReport();
            if (!configured) openSettings();
            return 0;
        },
        WM_TIMER => {
            showReport();
            return 0;
        },
        WM_COMMAND => {
            switch (wp & 0xffff) {
                ID_SETTINGS => openSettings(),
                ID_REFRESH => showReport(),
                ID_EXIT => PostQuitMessage(0),
                else => {},
            }
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
    loadModules();
    brush = CreateSolidBrush(0x00181012);
    const inst = GetModuleHandleA(null);
    const main_class = WNDCLASSA{ .lpfnWndProc = mainProc, .hInstance = inst, .hbrBackground = brush, .lpszClassName = "AmericaOnlineHost" };
    _ = RegisterClassA(&main_class);
    main_hwnd = CreateWindowExA(0, "AmericaOnlineHost", "America Online - Host", WS_OVERLAPPEDWINDOW, 40, 30, 780, 500, null, null, inst, null).?;
    const bar = CreateMenu();
    const pool_menu = CreatePopupMenu();
    _ = AppendMenuA(pool_menu, MF_STRING, ID_SETTINGS, "Settings...");
    _ = AppendMenuA(pool_menu, MF_STRING, ID_REFRESH, "Refresh report");
    _ = AppendMenuA(pool_menu, MF_STRING, ID_EXIT, "Exit");
    _ = AppendMenuA(bar, MF_POPUP, @intFromPtr(pool_menu), "Pool");
    _ = SetMenu(main_hwnd, bar);
    _ = ShowWindow(main_hwnd, 5);
    var message: MSG = undefined;
    while (GetMessageA(&message, null, 0, 0) != 0) {
        _ = TranslateMessage(&message);
        _ = DispatchMessageA(&message);
    }
}
