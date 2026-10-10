const std = @import("std");
const WINAPI = std.os.windows.WINAPI;
const HWND = *opaque {};
const HINSTANCE = *opaque {};
const HBRUSH = *opaque {};
const LRESULT = isize;
const WPARAM = usize;
const LPARAM = isize;
const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
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
extern "user32" fn DispatchMessageA(msg: *const MSG) callconv(WINAPI) LRESULT;
extern "user32" fn DefWindowProcA(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT;
extern "user32" fn PostQuitMessage(code: i32) callconv(WINAPI) void;
extern "user32" fn SetWindowTextA(hwnd: HWND, text: [*:0]const u8) callconv(WINAPI) i32;
extern "user32" fn GetWindowTextA(hwnd: HWND, buf: [*]u8, max: i32) callconv(WINAPI) i32;
extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(WINAPI) HINSTANCE;
extern "gdi32" fn CreateSolidBrush(color: u32) callconv(WINAPI) HBRUSH;

const WS_OVERLAPPEDWINDOW: u32 = 0x00CF0000;
const WS_CHILD: u32 = 0x40000000;
const WS_VISIBLE: u32 = 0x10000000;
const WS_BORDER: u32 = 0x00800000;
const WM_DESTROY: u32 = 2;
const WM_COMMAND: u32 = 0x0111;
const WM_CTLCOLORSTATIC: u32 = 0x0138;

var log_box: HWND = undefined;
var repo_box: HWND = undefined;
var brush: HBRUSH = undefined;

fn child(parent: HWND, class: [*:0]const u8, title: [*:0]const u8, style: u32, x: i32, y: i32, w: i32, h: i32, id: usize) HWND {
    return CreateWindowExA(0, class, title, style, x, y, w, h, parent, @ptrFromInt(id), GetModuleHandleA(null), null).?;
}

fn note(text: []const u8) void {
    var z: [240]u8 = undefined;
    const n = @min(text.len, z.len - 1);
    @memcpy(z[0..n], text[0..n]);
    z[n] = 0;
    _ = SetWindowTextA(log_box, z[0..n :0]);
}

fn wnd(window: HWND, msg: u32, wp: WPARAM, lp: LPARAM) callconv(WINAPI) LRESULT {
    switch (msg) {
        1 => {
            _ = child(window, "STATIC", "AMERICA  Online", WS_CHILD | WS_VISIBLE, 16, 12, 280, 22, 1);
            _ = child(window, "STATIC", "The host is awake. The rooms are counting.", WS_CHILD | WS_VISIBLE, 16, 36, 420, 18, 2);
            _ = child(window, "STATIC", "8080 sign-on    3333-3338 the pool    /admin the coin", WS_CHILD | WS_VISIBLE, 16, 58, 460, 18, 3);
            log_box = child(window, "STATIC", "party.db keeps the night. aol.db keeps the names.", WS_CHILD | WS_VISIBLE | WS_BORDER, 16, 88, 520, 36, 4);
            repo_box = child(window, "EDIT", "https://github.com/5mil/orthal.git", WS_CHILD | WS_VISIBLE | WS_BORDER, 16, 140, 400, 22, 5);
            _ = child(window, "BUTTON", "Fetch coin", WS_CHILD | WS_VISIBLE, 424, 138, 110, 26, 6);
            _ = child(window, "BUTTON", "Pool status", WS_CHILD | WS_VISIBLE, 16, 176, 120, 26, 7);
            _ = child(window, "STATIC", "Set AOL_ADMIN before the coin. The flag was already up.", WS_CHILD | WS_VISIBLE, 16, 214, 460, 18, 8);
            return 0;
        },
        WM_CTLCOLORSTATIC => return @bitCast(@intFromPtr(brush)),
        WM_COMMAND => {
            if ((wp & 0xffff) == 7) note("Open http://127.0.0.1:8080/api/pool  The party total is there.");
            if ((wp & 0xffff) == 6) note("Paste the repo, then use /admin with AOL_ADMIN. The console fetch is the same door.");
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
    const window = CreateWindowExA(0, "AmericaOnlineHost", "America Online — Host", WS_OVERLAPPEDWINDOW, 120, 80, 580, 300, null, null, inst, null).?;
    _ = ShowWindow(window, 5);
    var message: MSG = undefined;
    while (GetMessageA(&message, null, 0, 0) != 0) _ = DispatchMessageA(&message);
}
