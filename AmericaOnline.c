/* America Online — People Connection
   Windows client. Same rooms as the lobby branch page.
   Messages go through the public ntfy relay. Nothing private. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define IDC_NAME 101
#define IDC_ROOM 102
#define IDC_SIGN 103
#define IDC_LOG 104
#define IDC_IN 105
#define IDC_SEND 106
#define IDC_ROOMS 107
#define IDC_WHO 108
#define IDC_STATUS 109
#define WM_NET (WM_APP + 1)

static const char *ROOMS[] = {"Lobby", "Thirtysomething", "Computer Help", "Sports Bar", "New Member Lounge"};
static const char *SLUGS[] = {"lobby", "thirtysomething", "computer-help", "sports-bar", "new-member-lounge"};
static HWND g_hwnd, g_name, g_room, g_sign, g_log, g_in, g_send, g_rooms, g_who, g_status;
static char g_screen[32];
static char g_slug[64];
static char g_since[64] = "10m";
static volatile LONG g_online;
static HANDLE g_thread;

static void slug_for(int i, char *out) {
    strcpy(out, SLUGS[i]);
}

static void ui(const char *text) {
    char *copy = (char *)HeapAlloc(GetProcessHeap(), 0, strlen(text) + 1);
    if (!copy) return;
    strcpy(copy, text);
    PostMessageA(g_hwnd, WM_NET, 0, (LPARAM)copy);
}

static int http_call(const wchar_t *verb, const wchar_t *path, const char *body, char *out, int outlen) {
    HINTERNET ses = WinHttpOpen(L"AmericaOnline/5.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!ses) return 0;
    HINTERNET con = WinHttpConnect(ses, L"ntfy.sh", INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (!con) { WinHttpCloseHandle(ses); return 0; }
    HINTERNET req = WinHttpOpenRequest(con, verb, path, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE);
    if (!req) { WinHttpCloseHandle(con); WinHttpCloseHandle(ses); return 0; }
    const wchar_t *hdr = L"Content-Type: text/plain\r\n";
    DWORD blen = body ? (DWORD)strlen(body) : 0;
    BOOL ok = WinHttpSendRequest(req, hdr, (DWORD)-1, body ? (LPVOID)body : WINHTTP_NO_REQUEST_DATA, blen, blen, 0);
    if (ok) ok = WinHttpReceiveResponse(req, NULL);
    int n = 0;
    if (ok && out && outlen > 1) {
        DWORD got = 0;
        while (n < outlen - 1 && WinHttpReadData(req, out + n, outlen - 1 - n, &got) && got) n += (int)got;
        out[n] = 0;
    }
    WinHttpCloseHandle(req);
    WinHttpCloseHandle(con);
    WinHttpCloseHandle(ses);
    return ok ? (n ? n : 1) : 0;
}

static void json_escape(const char *in, char *out, int n) {
    int j = 0;
    for (int i = 0; in[i] && j < n - 2; i++) {
        char c = in[i];
        if (c == '"' || c == '\\') { out[j++] = '\\'; out[j++] = c; }
        else if (c == '\n' || c == '\r') out[j++] = ' ';
        else out[j++] = c;
    }
    out[j] = 0;
}

static void publish(const char *kind, const char *name, const char *text) {
    char esc[400], body[640], path[128];
    wchar_t wpath[128];
    json_escape(text ? text : "", esc, sizeof(esc));
    snprintf(body, sizeof(body), "{\"kind\":\"%s\",\"name\":\"%s\",\"text\":\"%s\",\"id\":\"%lu\"}", kind, name, esc, GetTickCount());
    snprintf(path, sizeof(path), "/thimble-aol-%s", g_slug);
    MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, 128);
    http_call(L"POST", wpath, body, NULL, 0);
}

static void field(const char *json, const char *key, char *out, int n) {
    char pat[40];
    snprintf(pat, sizeof(pat), "\"%s\":\"", key);
    const char *p = strstr(json, pat);
    out[0] = 0;
    if (!p) return;
    p += strlen(pat);
    int j = 0;
    while (*p && *p != '"' && j < n - 1) {
        if (*p == '\\' && p[1]) { p++; }
        out[j++] = *p++;
    }
    out[j] = 0;
}

static void handle_line(const char *line) {
    char id[48], message[800], kind[16], name[40], text[400];
    field(line, "id", id, sizeof(id));
    field(line, "message", message, sizeof(message));
    if (id[0]) strncpy(g_since, id, sizeof(g_since) - 1);
    if (!message[0]) return;
    field(message, "kind", kind, sizeof(kind));
    field(message, "name", name, sizeof(name));
    field(message, "text", text, sizeof(text));
    if (!name[0]) return;
    char shown[500];
    if (!strcmp(kind, "chat")) snprintf(shown, sizeof(shown), "%s:  %s", name, text);
    else if (!strcmp(kind, "join")) snprintf(shown, sizeof(shown), "%s has entered the room.", name);
    else if (!strcmp(kind, "leave")) snprintf(shown, sizeof(shown), "%s has left the room.", name);
    else return;
    ui(shown);
}

static DWORD WINAPI poll_thread(LPVOID unused) {
    (void)unused;
    while (g_online) {
        char path[160], raw[48000];
        wchar_t wpath[160];
        snprintf(path, sizeof(path), "/thimble-aol-%s/json?poll=1&since=%s", g_slug, g_since);
        MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, 160);
        if (http_call(L"GET", wpath, NULL, raw, sizeof(raw))) {
            char *p = raw;
            while (*p) {
                char *nl = strchr(p, '\n');
                if (nl) *nl = 0;
                if (*p) handle_line(p);
                if (!nl) break;
                p = nl + 1;
            }
        }
        for (int i = 0; i < 20 && g_online; i++) Sleep(100);
    }
    return 0;
}

static void set_online_ui(BOOL on) {
    ShowWindow(g_name, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_room, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_sign, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_log, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_in, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_send, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_rooms, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_who, on ? SW_SHOW : SW_HIDE);
    if (on) SetWindowTextA(g_hwnd, "America Online — People Connection");
    else SetWindowTextA(g_hwnd, "America Online — Sign On");
}

static void sign_on(void) {
    char name[32];
    GetWindowTextA(g_name, name, 31);
    int n = (int)strlen(name);
    if (n < 3 || n > 16 || strchr(name, ' ')) {
        MessageBoxA(g_hwnd, "Screen names are 3 to 16 characters with no spaces.", "America Online", MB_OK);
        return;
    }
    strcpy(g_screen, name);
    int room = (int)SendMessageA(g_room, CB_GETCURSEL, 0, 0);
    if (room < 0) room = 0;
    slug_for(room, g_slug);
    strcpy(g_since, "10m");
    SendMessageA(g_log, LB_RESETCONTENT, 0, 0);
    set_online_ui(TRUE);
    char status[128];
    snprintf(status, sizeof(status), "Online — %s — %s", g_screen, ROOMS[room]);
    SetWindowTextA(g_status, status);
    g_online = 1;
    publish("join", g_screen, "");
    g_thread = CreateThread(NULL, 0, poll_thread, NULL, 0, NULL);
    Beep(2100, 80);
}

static void sign_off(void) {
    if (g_online) {
        g_online = 0;
        publish("leave", g_screen, "");
        if (g_thread) { WaitForSingleObject(g_thread, 2000); CloseHandle(g_thread); g_thread = NULL; }
    }
    set_online_ui(FALSE);
    SetWindowTextA(g_status, "Offline — modem speaker was a beep, the room was real");
}

static void send_chat(void) {
    if (!g_online) return;
    char text[240];
    GetWindowTextA(g_in, text, 239);
    if (!text[0]) return;
    SetWindowTextA(g_in, "");
    publish("chat", g_screen, text);
}

static void layout(void) {
    RECT r;
    GetClientRect(g_hwnd, &r);
    int w = r.right, h = r.bottom;
    MoveWindow(g_name, 24, 70, w - 48, 24, TRUE);
    MoveWindow(g_room, 24, 120, w - 48, 120, TRUE);
    MoveWindow(g_sign, w - 140, 160, 100, 28, TRUE);
    MoveWindow(g_rooms, 8, 8, 160, h - 64, TRUE);
    MoveWindow(g_log, 176, 8, w - 176 - 150, h - 64, TRUE);
    MoveWindow(g_who, w - 142, 8, 134, h - 64, TRUE);
    MoveWindow(g_in, 176, h - 50, w - 176 - 230, 24, TRUE);
    MoveWindow(g_send, w - 220, h - 52, 70, 26, TRUE);
    MoveWindow(g_status, 8, h - 22, w - 16, 18, TRUE);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        g_hwnd = hwnd;
        CreateWindowA("STATIC", "Select Screen Name", WS_CHILD | WS_VISIBLE, 24, 48, 200, 18, hwnd, NULL, NULL, NULL);
        g_name = CreateWindowA("EDIT", "SteveCaseFan", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, 24, 70, 300, 24, hwnd, (HMENU)IDC_NAME, NULL, NULL);
        CreateWindowA("STATIC", "People Connection room", WS_CHILD | WS_VISIBLE, 24, 100, 220, 18, hwnd, NULL, NULL, NULL);
        g_room = CreateWindowA("COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 24, 120, 300, 140, hwnd, (HMENU)IDC_ROOM, NULL, NULL);
        for (int i = 0; i < 5; i++) SendMessageA(g_room, CB_ADDSTRING, 0, (LPARAM)ROOMS[i]);
        SendMessageA(g_room, CB_SETCURSEL, 0, 0);
        g_sign = CreateWindowA("BUTTON", "Sign On", WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON, 24, 160, 100, 28, hwnd, (HMENU)IDC_SIGN, NULL, NULL);
        g_rooms = CreateWindowA("LISTBOX", "", WS_CHILD | LBS_NOTIFY | WS_BORDER | WS_VSCROLL, 8, 8, 160, 200, hwnd, (HMENU)IDC_ROOMS, NULL, NULL);
        for (int i = 0; i < 5; i++) SendMessageA(g_rooms, LB_ADDSTRING, 0, (LPARAM)ROOMS[i]);
        g_log = CreateWindowA("LISTBOX", "", WS_CHILD | WS_BORDER | WS_VSCROLL | LBS_NOINTEGRALHEIGHT, 176, 8, 400, 300, hwnd, (HMENU)IDC_LOG, NULL, NULL);
        g_who = CreateWindowA("LISTBOX", "", WS_CHILD | WS_BORDER | WS_VSCROLL, 580, 8, 120, 300, hwnd, (HMENU)IDC_WHO, NULL, NULL);
        g_in = CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 176, 320, 300, 24, hwnd, (HMENU)IDC_IN, NULL, NULL);
        g_send = CreateWindowA("BUTTON", "Send", WS_CHILD | BS_DEFPUSHBUTTON, 490, 318, 70, 26, hwnd, (HMENU)IDC_SEND, NULL, NULL);
        g_status = CreateWindowA("STATIC", "Offline. Sign on to join a live room.", WS_CHILD | WS_VISIBLE, 8, 360, 500, 18, hwnd, (HMENU)IDC_STATUS, NULL, NULL);
        CreateWindowA("STATIC", "AMERICA  Online", WS_CHILD | WS_VISIBLE, 24, 12, 260, 24, hwnd, NULL, NULL, NULL);
        layout();
        return 0;
    }
    case WM_SIZE:
        layout();
        return 0;
    case WM_COMMAND:
        if (LOWORD(wp) == IDC_SIGN) sign_on();
        if (LOWORD(wp) == IDC_SEND) send_chat();
        if (LOWORD(wp) == IDC_IN && HIWORD(wp) == EN_CHANGE) {}
        if (HIWORD(wp) == LBN_DBLCLK && LOWORD(wp) == IDC_ROOMS && g_online) {
            int i = (int)SendMessageA(g_rooms, LB_GETCURSEL, 0, 0);
            if (i >= 0) {
                publish("leave", g_screen, "");
                slug_for(i, g_slug);
                strcpy(g_since, "10m");
                SendMessageA(g_log, LB_RESETCONTENT, 0, 0);
                char status[128];
                snprintf(status, sizeof(status), "Online — %s — %s", g_screen, ROOMS[i]);
                SetWindowTextA(g_status, status);
                publish("join", g_screen, "");
            }
        }
        return 0;
    case WM_NET: {
        char *text = (char *)lp;
        if (text) {
            SendMessageA(g_log, LB_ADDSTRING, 0, (LPARAM)text);
            int count = (int)SendMessageA(g_log, LB_GETCOUNT, 0, 0);
            SendMessageA(g_log, LB_SETTOPINDEX, count - 1, 0);
            if (strncmp(text, g_screen, strlen(g_screen)) != 0) Beep(880, 40);
            HeapFree(GetProcessHeap(), 0, text);
        }
        return 0;
    }
    case WM_KEYDOWN:
        if (wp == VK_RETURN && g_online) send_chat();
        return 0;
    case WM_DESTROY:
        sign_off();
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcA(hwnd, msg, wp, lp);
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show) {
    (void)prev; (void)cmd;
    WNDCLASSA wc = {0};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.lpszClassName = "AmericaOnlineChat";
    wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassA(&wc);
    HWND hwnd = CreateWindowA("AmericaOnlineChat", "America Online — Sign On", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 760, 480, NULL, NULL, inst, NULL);
    ShowWindow(hwnd, show);
    MSG msg;
    while (GetMessageA(&msg, NULL, 0, 0)) {
        if (msg.message == WM_KEYDOWN && msg.wParam == VK_RETURN && g_online) send_chat();
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
    return 0;
}
