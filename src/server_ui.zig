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
