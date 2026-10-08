/* America Online for Windows.
   Talks to server.py: sign up, sign on, rooms, mail.
   Password is sent to the host you type. It is not saved in the program. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define IDC_HOST 101
#define IDC_PORT 102
#define IDC_NAME 103
#define IDC_PASS 104
#define IDC_ROOM 105
#define IDC_SIGNUP 106
#define IDC_SIGN 107
#define IDC_LOG 108
#define IDC_IN 109
#define IDC_SEND 110
#define IDC_ROOMS 111
#define IDC_MAIL 112
#define IDC_STATUS 113
#define WM_NET (WM_APP + 1)

static const char *ROOMS[] = {"Lobby", "Thirtysomething", "Computer Help", "Sports Bar", "New Member Lounge"};
static HWND g_hwnd, g_host, g_port, g_name, g_pass, g_room, g_signup, g_sign;
static HWND g_log, g_in, g_send, g_rooms, g_mail, g_status;
static char g_screen[32], g_token[80], g_host_s[80];
static int g_port_n = 8080, g_room_i, g_since;
static volatile LONG g_online;
static HANDLE g_thread;

static void ui(const char *text) {
    char *copy = (char *)HeapAlloc(GetProcessHeap(), 0, strlen(text) + 1);
    if (!copy) return;
    strcpy(copy, text);
    PostMessageA(g_hwnd, WM_NET, 0, (LPARAM)copy);
}

static int http_call(const wchar_t *verb, const wchar_t *path, const char *body, const char *token, char *out, int outlen) {
    wchar_t whost[80];
    MultiByteToWideChar(CP_UTF8, 0, g_host_s, -1, whost, 80);
    HINTERNET ses = WinHttpOpen(L"AmericaOnline/5.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!ses) return 0;
    HINTERNET con = WinHttpConnect(ses, whost, (INTERNET_PORT)g_port_n, 0);
    if (!con) { WinHttpCloseHandle(ses); return 0; }
    HINTERNET req = WinHttpOpenRequest(con, verb, path, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
    if (!req) { WinHttpCloseHandle(con); WinHttpCloseHandle(ses); return 0; }
    wchar_t hdr[200], wtoken[80];
    if (token && token[0]) {
        MultiByteToWideChar(CP_UTF8, 0, token, -1, wtoken, 80);
        swprintf(hdr, 200, L"Content-Type: application/json\r\nAuthorization: Bearer %s\r\n", wtoken);
    } else wcscpy(hdr, L"Content-Type: application/json\r\n");
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
    return ok ? 1 : 0;
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
        if (*p == '\\' && p[1]) p++;
        out[j++] = *p++;
    }
    out[j] = 0;
}

static void json_escape(const char *in, char *out, int n) {
    int j = 0;
    for (int i = 0; in[i] && j < n - 2; i++) {
        if (in[i] == '"' || in[i] == '\\') { out[j++] = '\\'; out[j++] = in[i]; }
        else if (in[i] == '\n' || in[i] == '\r') out[j++] = ' ';
        else out[j++] = in[i];
    }
    out[j] = 0;
}

static void set_online_ui(BOOL on) {
    int sign[] = {0};
    ShowWindow(g_host, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_port, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_name, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_pass, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_room, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_signup, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_sign, on ? SW_HIDE : SW_SHOW);
    ShowWindow(g_log, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_in, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_send, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_rooms, on ? SW_SHOW : SW_HIDE);
    ShowWindow(g_mail, on ? SW_SHOW : SW_HIDE);
    (void)sign;
    SetWindowTextA(g_hwnd, on ? "America Online — People Connection" : "America Online — Sign On");
}

static int auth(const char *path) {
    char name[32], pass[64], body[200], raw[800], token[80], screen[32];
    GetWindowTextA(g_name, name, 31);
    GetWindowTextA(g_pass, pass, 63);
    GetWindowTextA(g_host, g_host_s, 79);
    char port[8];
    GetWindowTextA(g_port, port, 7);
    g_port_n = atoi(port);
    if (!g_port_n) g_port_n = 8080;
    json_escape(name, screen, sizeof(screen));
    json_escape(pass, token, sizeof(token));
    snprintf(body, sizeof(body), "{\"screenName\":\"%s\",\"password\":\"%s\"}", screen, token);
    if (!http_call(L"POST", path[0] == 's' ? L"/api/signup" : L"/api/login", body, NULL, raw, sizeof(raw))) {
        MessageBoxA(g_hwnd, "The server did not answer. Start server.py on that host.", "America Online", MB_OK);
        return 0;
    }
    if (!strstr(raw, "\"ok\": true") && !strstr(raw, "\"ok\":true")) {
        char err[180];
        field(raw, "error", err, sizeof(err));
        MessageBoxA(g_hwnd, err[0] ? err : raw, "America Online", MB_OK);
        return 0;
    }
    field(raw, "token", g_token, sizeof(g_token));
    field(raw, "screenName", g_screen, sizeof(g_screen));
    g_room_i = (int)SendMessageA(g_room, CB_GETCURSEL, 0, 0);
    if (g_room_i < 0) g_room_i = 0;
    g_since = 0;
    g_online = 1;
    SendMessageA(g_log, LB_RESETCONTENT, 0, 0);
    set_online_ui(TRUE);
    char status[160];
    snprintf(status, sizeof(status), "Online — %s — %s — %s:%d", g_screen, ROOMS[g_room_i], g_host_s, g_port_n);
    SetWindowTextA(g_status, status);
    return 1;
}

static DWORD WINAPI poll_thread(LPVOID unused) {
    (void)unused;
    while (g_online) {
        char path[160], raw[16000];
        wchar_t wpath[160];
        snprintf(path, sizeof(path), "/api/messages?room=%s&since=%d", ROOMS[g_room_i], g_since);
        for (char *p = path; *p; p++) if (*p == ' ') *p = '+';
        MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, 160);
        if (http_call(L"GET", wpath, NULL, g_token, raw, sizeof(raw))) {
            const char *p = raw;
            while ((p = strstr(p, "\"id\":"))) {
                int id = atoi(p + 5);
                char name[40], body[300], shown[360];
                field(p, "name", name, sizeof(name));
                field(p, "body", body, sizeof(body));
                if (id > g_since && name[0]) {
                    g_since = id;
                    snprintf(shown, sizeof(shown), "%s:  %s", name, body);
                    ui(shown);
                }
                p += 5;
            }
        }
        for (int i = 0; i < 20 && g_online; i++) Sleep(100);
    }
    return 0;
}

static void start_session(const char *which) {
    if (!auth(which)) return;
    if (g_thread) CloseHandle(g_thread);
    g_thread = CreateThread(NULL, 0, poll_thread, NULL, 0, NULL);
}

static void send_chat(void) {
    if (!g_online) return;
    char text[240], esc[480], body[640], raw[200];
    wchar_t wpath[80];
    GetWindowTextA(g_in, text, 239);
    if (!text[0]) return;
    SetWindowTextA(g_in, "");
    json_escape(text, esc, sizeof(esc));
    snprintf(body, sizeof(body), "{\"room\":\"%s\",\"text\":\"%s\"}", ROOMS[g_room_i], esc);
    wcscpy(wpath, L"/api/messages");
    http_call(L"POST", wpath, body, g_token, raw, sizeof(raw));
}

static void read_mail(void) {
    char raw[8000];
    if (!http_call(L"GET", L"/api/mail", NULL, g_token, raw, sizeof(raw))) return;
    ui("--- Mail ---");
    const char *p = raw;
    int any = 0;
    while ((p = strstr(p, "\"subject\":\""))) {
        char subject[80], sender[40], body[240], shown[400];
        field(p, "subject", subject, sizeof(subject));
        field(p, "sender", sender, sizeof(sender));
        field(p, "body", body, sizeof(body));
        snprintf(shown, sizeof(shown), "Mail from %s: %s — %s", sender, subject, body);
        ui(shown);
        any = 1;
        p += 11;
    }
    if (!any) ui("No mail.");
}

static void layout(void) {
    RECT r;
    GetClientRect(g_hwnd, &r);
    int w = r.right, h = r.bottom;
    MoveWindow(g_host, 24, 56, 180, 22, TRUE);
    MoveWindow(g_port, 212, 56, 70, 22, TRUE);
    MoveWindow(g_name, 24, 104, 260, 22, TRUE);
    MoveWindow(g_pass, 24, 150, 260, 22, TRUE);
    MoveWindow(g_room, 24, 196, 260, 120, TRUE);
    MoveWindow(g_signup, 24, 236, 100, 28, TRUE);
    MoveWindow(g_sign, 136, 236, 100, 28, TRUE);
    MoveWindow(g_rooms, 8, 8, 160, h - 64, TRUE);
    MoveWindow(g_log, 176, 8, w - 184, h - 92, TRUE);
    MoveWindow(g_in, 176, h - 76, w - 280, 22, TRUE);
    MoveWindow(g_send, w - 96, h - 78, 80, 26, TRUE);
    MoveWindow(g_mail, 8, h - 48, 160, 24, TRUE);
    MoveWindow(g_status, 176, h - 46, w - 190, 18, TRUE);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE:
        g_hwnd = hwnd;
        CreateWindowA("STATIC", "Server host and port", WS_CHILD | WS_VISIBLE, 24, 36, 220, 16, hwnd, NULL, NULL, NULL);
        g_host = CreateWindowA("EDIT", "127.0.0.1", WS_CHILD | WS_VISIBLE | WS_BORDER, 24, 56, 180, 22, hwnd, (HMENU)IDC_HOST, NULL, NULL);
        g_port = CreateWindowA("EDIT", "8080", WS_CHILD | WS_VISIBLE | WS_BORDER, 212, 56, 70, 22, hwnd, (HMENU)IDC_PORT, NULL, NULL);
        CreateWindowA("STATIC", "Select Screen Name", WS_CHILD | WS_VISIBLE, 24, 86, 200, 16, hwnd, NULL, NULL, NULL);
        g_name = CreateWindowA("EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER, 24, 104, 260, 22, hwnd, (HMENU)IDC_NAME, NULL, NULL);
        CreateWindowA("STATIC", "Enter Password", WS_CHILD | WS_VISIBLE, 24, 132, 200, 16, hwnd, NULL, NULL, NULL);
        g_pass = CreateWindowA("EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_PASSWORD, 24, 150, 260, 22, hwnd, (HMENU)IDC_PASS, NULL, NULL);
        CreateWindowA("STATIC", "Room", WS_CHILD | WS_VISIBLE, 24, 178, 80, 16, hwnd, NULL, NULL, NULL);
        g_room = CreateWindowA("COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, 24, 196, 260, 140, hwnd, (HMENU)IDC_ROOM, NULL, NULL);
        for (int i = 0; i < 5; i++) SendMessageA(g_room, CB_ADDSTRING, 0, (LPARAM)ROOMS[i]);
        SendMessageA(g_room, CB_SETCURSEL, 0, 0);
        g_signup = CreateWindowA("BUTTON", "Sign Up", WS_CHILD | WS_VISIBLE, 24, 236, 100, 28, hwnd, (HMENU)IDC_SIGNUP, NULL, NULL);
        g_sign = CreateWindowA("BUTTON", "Sign On", WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON, 136, 236, 100, 28, hwnd, (HMENU)IDC_SIGN, NULL, NULL);
        g_rooms = CreateWindowA("LISTBOX", "", WS_CHILD | LBS_NOTIFY | WS_BORDER, 8, 8, 160, 200, hwnd, (HMENU)IDC_ROOMS, NULL, NULL);
        for (int i = 0; i < 5; i++) SendMessageA(g_rooms, LB_ADDSTRING, 0, (LPARAM)ROOMS[i]);
        g_log = CreateWindowA("LISTBOX", "", WS_CHILD | WS_BORDER | WS_VSCROLL | LBS_NOINTEGRALHEIGHT, 176, 8, 400, 280, hwnd, (HMENU)IDC_LOG, NULL, NULL);
        g_in = CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 176, 300, 300, 22, hwnd, (HMENU)IDC_IN, NULL, NULL);
        g_send = CreateWindowA("BUTTON", "Send", WS_CHILD, 490, 298, 70, 26, hwnd, (HMENU)IDC_SEND, NULL, NULL);
        g_mail = CreateWindowA("BUTTON", "You've Got Mail", WS_CHILD, 8, 320, 150, 24, hwnd, (HMENU)IDC_MAIL, NULL, NULL);
        g_status = CreateWindowA("STATIC", "Offline. Run server.py, then sign up.", WS_CHILD | WS_VISIBLE, 24, 276, 420, 18, hwnd, (HMENU)IDC_STATUS, NULL, NULL);
        CreateWindowA("STATIC", "AMERICA  Online", WS_CHILD | WS_VISIBLE, 24, 8, 240, 22, hwnd, NULL, NULL, NULL);
        layout();
        return 0;
    case WM_SIZE: layout(); return 0;
    case WM_COMMAND:
        if (LOWORD(wp) == IDC_SIGNUP) start_session("signup");
        if (LOWORD(wp) == IDC_SIGN) start_session("login");
        if (LOWORD(wp) == IDC_SEND) send_chat();
        if (LOWORD(wp) == IDC_MAIL && g_online) read_mail();
        if (HIWORD(wp) == LBN_DBLCLK && LOWORD(wp) == IDC_ROOMS && g_online) {
            int i = (int)SendMessageA(g_rooms, LB_GETCURSEL, 0, 0);
            if (i >= 0) { g_room_i = i; g_since = 0; SendMessageA(g_log, LB_RESETCONTENT, 0, 0); ui("You have entered the room."); }
        }
        return 0;
    case WM_NET: {
        char *text = (char *)lp;
        if (text) {
            SendMessageA(g_log, LB_ADDSTRING, 0, (LPARAM)text);
            int count = (int)SendMessageA(g_log, LB_GETCOUNT, 0, 0);
            SendMessageA(g_log, LB_SETTOPINDEX, count - 1, 0);
            HeapFree(GetProcessHeap(), 0, text);
        }
        return 0;
    }
    case WM_DESTROY:
        g_online = 0;
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
    wc.lpszClassName = "AmericaOnlineHost";
    wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassA(&wc);
    HWND hwnd = CreateWindowA("AmericaOnlineHost", "America Online — Sign On", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 760, 480, NULL, NULL, inst, NULL);
    ShowWindow(hwnd, show);
    MSG msg;
    while (GetMessageA(&msg, NULL, 0, 0)) {
        if (msg.message == WM_KEYDOWN && msg.wParam == VK_RETURN && g_online) send_chat();
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
    return 0;
}
