/* America Online 5.0 recreation — native Win32 window, not a browser. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define APP_TITLE "America Online"
#define ID_SIGNON 1001
#define ID_SETUP 1002
#define ID_CANCELDIAL 1003
#define ID_NAME 1010
#define ID_PASS 1011
#define ID_LOC 1012
#define ID_SPEAKER 1013
#define ID_KEYWORD 1020
#define ID_GO 1021
#define ID_MAIL 1030
#define ID_CHATLOG 1031
#define ID_CHATIN 1032
#define ID_CHATSEND 1033
#define ID_BUDDY 1034
#define ID_READ 1040
#define ID_WRITE 1041
#define ID_DELETE 1042
#define ID_SENDMAIL 1043
#define ID_TO 1044
#define ID_SUBJ 1045
#define ID_BODY 1046
#define ID_TIMER_DIAL 1
#define ID_TIMER_CHAT 2
#define ID_TIMER_BYE 3
#define ID_TIMER_CLOCK 4

#define M_WELCOME 2001
#define M_CHANNELS 2002
#define M_MAIL 2003
#define M_COMPOSE 2004
#define M_PEOPLE 2005
#define M_BUDDY 2006
#define M_IM 2007
#define M_WEATHER 2008
#define M_STOCKS 2009
#define M_GAMES 2010
#define M_HELP 2011
#define M_ABOUT 2012
#define M_SIGNOFF 2013
#define M_EXIT 2014
#define M_NEWS 2015
#define M_SPORTS 2016
#define M_KIDS 2017
#define M_PICTURES 2018
#define M_INTERNET 2019
#define M_SENT 2020

enum { ST_SIGNON = 0, ST_DIAL, ST_ONLINE, ST_GOODBYE };
enum { VIEW_WELCOME = 0, VIEW_MAIL, VIEW_CHAT, VIEW_COMPOSE, VIEW_CHANNEL, VIEW_BUDDY };

typedef struct Mail {
    char from[32];
    char to[32];
    char subject[80];
    char body[400];
    char when[24];
    int unread;
    int sent;
} Mail;

static Mail g_mail[32];
static int g_mail_n = 0;
static int g_state = ST_SIGNON;
static int g_view = VIEW_WELCOME;
static int g_dial_step = 0;
static int g_seconds = 0;
static int g_busy = 0;
static int g_speaker = 1;
static char g_name[20] = "SteveCaseFan";
static char g_speed[24] = "";
static char g_channel[64] = "Welcome";
static char g_article[800] = "";
static HWND g_hwnd;
static HFONT g_font, g_font_big, g_font_script;
static HBRUSH g_navy, g_lavender, g_win, g_white, g_gold;

static const char *DIAL_STEPS[] = {
    "Initializing modem...",
    "Dialing access number...",
    "Ringing...",
    "Connecting at 28800 bps...",
    "Requesting network attention...",
    "Talking to network...",
    "Connecting to America Online...",
    "Checking password..."
};
#define DIAL_N 8

static const char *ROOMS[] = {
    "Lobby", "Romance", "Thirtysomething", "X-Files", "Sports Bar", "Computer Help", "New Member Lounge"
};
#define ROOM_N 7
static int g_room = 0;
static const char *CHATTERS[] = {
    "CoolDude95", "SoccerMom22", "BuffyFan", "XFilesRule", "NetNinja", "JazzCat", "ModemQueen"
};
static const char *LINES[] = {
    "brb phone", "lol", "anyone from ohio?", "the handshake took forever",
    "keyword news is slow", "wb", "gtg dinner", "56k tonight, barely", "is steve case in here? no."
};

static int valid_name(const char *s) {
    int n = (int)strlen(s);
    int i;
    if (n < 3 || n > 16) return 0;
    for (i = 0; i < n; i++) if (s[i] == ' ') return 0;
    return 1;
}

static const char *keyword_title(const char *k) {
    if (!k) return NULL;
    if (!_stricmp(k, "mail")) return "Mailbox";
    if (!_stricmp(k, "chat") || !_stricmp(k, "people")) return "People Connection";
    if (!_stricmp(k, "news")) return "Today's News";
    if (!_stricmp(k, "sports")) return "Sports";
    if (!_stricmp(k, "games")) return "Games";
    if (!_stricmp(k, "weather")) return "Weather";
    if (!_stricmp(k, "stocks") || !_stricmp(k, "quotes")) return "Quotes";
    if (!_stricmp(k, "kids")) return "Kids Only";
    if (!_stricmp(k, "finance")) return "Personal Finance";
    if (!_stricmp(k, "travel")) return "Travel";
    if (!_stricmp(k, "computing")) return "Computing";
    if (!_stricmp(k, "entertainment")) return "Entertainment";
    if (!_stricmp(k, "pictures")) return "You've Got Pictures";
    if (!_stricmp(k, "help")) return "Member Services";
    if (!_stricmp(k, "buddy") || !_stricmp(k, "im")) return "Buddy List";
    if (!_stricmp(k, "internet")) return "Internet";
    return NULL;
}

static void seed_mail(void) {
    g_mail_n = 0;
    lstrcpyA(g_mail[0].from, "AOLNewsAlert");
    lstrcpyA(g_mail[0].to, "SteveCaseFan");
    lstrcpyA(g_mail[0].subject, "You've Got Mail - and a news brief");
    lstrcpyA(g_mail[0].body, "Welcome back. Senate debate ran long. Hurricane watch on the Outer Banks. Keyword: NEWS");
    lstrcpyA(g_mail[0].when, "6:41 PM");
    g_mail[0].unread = 1; g_mail[0].sent = 0;
    lstrcpyA(g_mail[1].from, "CoolDude95");
    lstrcpyA(g_mail[1].to, "SteveCaseFan");
    lstrcpyA(g_mail[1].subject, "you on tonight?");
    lstrcpyA(g_mail[1].body, "meet in the lobby after you sign on.");
    lstrcpyA(g_mail[1].when, "5:12 PM");
    g_mail[1].unread = 1; g_mail[1].sent = 0;
    lstrcpyA(g_mail[2].from, "MemberServices");
    lstrcpyA(g_mail[2].to, "SteveCaseFan");
    lstrcpyA(g_mail[2].subject, "Your plan");
    lstrcpyA(g_mail[2].body, "This recreation does not bill you and does not dial a real line.");
    lstrcpyA(g_mail[2].when, "Yesterday");
    g_mail[2].unread = 1; g_mail[2].sent = 0;
    lstrcpyA(g_mail[3].from, "PictureMail");
    lstrcpyA(g_mail[3].to, "SteveCaseFan");
    lstrcpyA(g_mail[3].subject, "You've Got Pictures");
    lstrcpyA(g_mail[3].body, "Roll 2148 is ready. Keyword: PICTURES");
    lstrcpyA(g_mail[3].when, "Mon");
    g_mail[3].unread = 0; g_mail[3].sent = 0;
    g_mail_n = 4;
}

static int unread_count(void) {
    int i, n = 0;
    for (i = 0; i < g_mail_n; i++) if (!g_mail[i].sent && g_mail[i].unread) n++;
    return n;
}

static int selftest(char *out, int cap) {
    int pass = 0, fail = 0;
    char buf[1400];
    buf[0] = 0;
    #define CHECK(name, cond) do { \
        if (cond) { pass++; strcat(buf, "PASS  " name "\r\n"); } \
        else { fail++; strcat(buf, "FAIL  " name "\r\n"); } \
    } while (0)
    CHECK("screen name length", valid_name("SteveCaseFan") && !valid_name("ab") && !valid_name("has space"));
    CHECK("eight dial steps", DIAL_N == 8 && DIAL_STEPS[0][0] == 'I' && strstr(DIAL_STEPS[7], "password") != NULL);
    CHECK("connect speed step", strstr(DIAL_STEPS[3], "28800") != NULL);
    CHECK("network attention step", strstr(DIAL_STEPS[4], "network attention") != NULL);
    seed_mail();
    CHECK("mail seeded", g_mail_n >= 3 && unread_count() == 3);
    CHECK("keyword news", keyword_title("news") && strcmp(keyword_title("news"), "Today's News") == 0);
    CHECK("keyword chat", keyword_title("chat") != NULL);
    CHECK("keyword mail", keyword_title("MAIL") != NULL);
    CHECK("unknown keyword", keyword_title("not-a-real-keyword") == NULL);
    CHECK("rooms", ROOM_N >= 5);
    strcat(buf, fail ? "SELF-TEST FAILED\r\n" : "SELF-TEST OK\r\n");
    lstrcpynA(out, buf, cap);
    return fail == 0;
    #undef CHECK
}

static void draw_logo(HDC dc, int x, int y, int s) {
    POINT tri[3];
    HBRUSH oldb;
    HPEN oldp, pen;
    tri[0].x = x + s/2; tri[0].y = y;
    tri[1].x = x + s; tri[1].y = y + s;
    tri[2].x = x; tri[2].y = y + s;
    oldb = SelectObject(dc, g_navy);
    pen = CreatePen(PS_SOLID, 1, RGB(10, 30, 90));
    oldp = SelectObject(dc, pen);
    Polygon(dc, tri, 3);
    SelectObject(dc, g_white);
    Ellipse(dc, x + s/2 - s/5, y + s/2 - s/8, x + s/2 + s/5, y + s/2 + s/3);
    SelectObject(dc, g_gold);
    Ellipse(dc, x + s/5, y + s/2, x + s/5 + s/6, y + s/2 + s/6);
    SelectObject(dc, oldb);
    SelectObject(dc, oldp);
    DeleteObject(pen);
}

static void set_title(void) {
    char t[128];
    if (g_state == ST_SIGNON) wsprintfA(t, "America Online - Sign On");
    else if (g_state == ST_DIAL) wsprintfA(t, "America Online - Dialing");
    else if (g_state == ST_GOODBYE) wsprintfA(t, "Goodbye");
    else wsprintfA(t, "America Online - %s", g_name);
    SetWindowTextA(g_hwnd, t);
}

static void layout_online(void) {
    RECT rc;
    int w, h, top = 78;
    GetClientRect(g_hwnd, &rc);
    w = rc.right; h = rc.bottom;
    ShowWindow(GetDlgItem(g_hwnd, ID_KEYWORD), SW_SHOW);
    ShowWindow(GetDlgItem(g_hwnd, ID_GO), SW_SHOW);
    MoveWindow(GetDlgItem(g_hwnd, ID_KEYWORD), w - 230, 32, 140, 22, TRUE);
    MoveWindow(GetDlgItem(g_hwnd, ID_GO), w - 84, 32, 70, 22, TRUE);
    ShowWindow(GetDlgItem(g_hwnd, ID_MAIL), g_view == VIEW_MAIL ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_READ), g_view == VIEW_MAIL ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_WRITE), g_view == VIEW_MAIL ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_DELETE), g_view == VIEW_MAIL ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_CHATLOG), g_view == VIEW_CHAT ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_CHATIN), g_view == VIEW_CHAT ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_CHATSEND), g_view == VIEW_CHAT ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_BUDDY), (g_view == VIEW_WELCOME || g_view == VIEW_BUDDY) ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_TO), g_view == VIEW_COMPOSE ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_SUBJ), g_view == VIEW_COMPOSE ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_BODY), g_view == VIEW_COMPOSE ? SW_SHOW : SW_HIDE);
    ShowWindow(GetDlgItem(g_hwnd, ID_SENDMAIL), g_view == VIEW_COMPOSE ? SW_SHOW : SW_HIDE);
    if (g_view == VIEW_MAIL) {
        MoveWindow(GetDlgItem(g_hwnd, ID_READ), 16, top, 80, 24, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_WRITE), 102, top, 80, 24, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_DELETE), 188, top, 80, 24, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_MAIL), 16, top + 30, w - 32, h - top - 58, TRUE);
    }
    if (g_view == VIEW_CHAT) {
        MoveWindow(GetDlgItem(g_hwnd, ID_CHATLOG), 16, top, w - 32, h - top - 90, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_CHATIN), 16, h - 52, w - 120, 24, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_CHATSEND), w - 96, h - 52, 80, 24, TRUE);
    }
    if (g_view == VIEW_WELCOME || g_view == VIEW_BUDDY) {
        MoveWindow(GetDlgItem(g_hwnd, ID_BUDDY), w - 190, top, 174, h - top - 36, TRUE);
    }
    if (g_view == VIEW_COMPOSE) {
        MoveWindow(GetDlgItem(g_hwnd, ID_TO), 70, top, w - 90, 22, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_SUBJ), 70, top + 28, w - 90, 22, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_BODY), 16, top + 58, w - 32, h - top - 120, TRUE);
        MoveWindow(GetDlgItem(g_hwnd, ID_SENDMAIL), 16, h - 52, 100, 24, TRUE);
    }
}

static void show_signon(BOOL on) {
    int ids[] = { ID_NAME, ID_PASS, ID_LOC, ID_SPEAKER, ID_SIGNON, ID_SETUP };
    int i;
    for (i = 0; i < 6; i++) ShowWindow(GetDlgItem(g_hwnd, ids[i]), on ? SW_SHOW : SW_HIDE);
    if (!on) {
        int hide[] = { ID_KEYWORD, ID_GO, ID_MAIL, ID_READ, ID_WRITE, ID_DELETE, ID_CHATLOG, ID_CHATIN, ID_CHATSEND, ID_BUDDY, ID_TO, ID_SUBJ, ID_BODY, ID_SENDMAIL };
        for (i = 0; i < 14; i++) ShowWindow(GetDlgItem(g_hwnd, hide[i]), SW_HIDE);
    }
}

static void fill_mail(void) {
    HWND lb = GetDlgItem(g_hwnd, ID_MAIL);
    int i;
    SendMessageA(lb, LB_RESETCONTENT, 0, 0);
    for (i = 0; i < g_mail_n; i++) if (!g_mail[i].sent) {
        char line[160];
        wsprintfA(line, "%s  %-14s  %s", g_mail[i].unread ? "NEW" : "   ", g_mail[i].from, g_mail[i].subject);
        SendMessageA(lb, LB_ADDSTRING, 0, (LPARAM)line);
        SendMessageA(lb, LB_SETITEMDATA, SendMessageA(lb, LB_GETCOUNT, 0, 0) - 1, i);
    }
}

static void fill_buddy(void) {
    HWND lb = GetDlgItem(g_hwnd, ID_BUDDY);
    int i;
    SendMessageA(lb, LB_RESETCONTENT, 0, 0);
    SendMessageA(lb, LB_ADDSTRING, 0, (LPARAM)"Buddies Online");
    for (i = 0; i < 5; i++) SendMessageA(lb, LB_ADDSTRING, 0, (LPARAM)CHATTERS[i]);
}

static void enter_online(void) {
    g_state = ST_ONLINE;
    g_view = VIEW_WELCOME;
    g_seconds = 0;
    lstrcpyA(g_speed, "28800 bps");
    lstrcpyA(g_channel, "Welcome");
    lstrcpyA(g_article, "Welcome. Channels are on the menu. Keyword box is at the top right. People Connection is the lobby.");
    show_signon(FALSE);
    layout_online();
    fill_buddy();
    set_title();
    SetTimer(g_hwnd, ID_TIMER_CLOCK, 1000, NULL);
    InvalidateRect(g_hwnd, NULL, TRUE);
    if (g_speaker) {
        Beep(523, 90);
        Beep(659, 140);
    }
    MessageBoxA(g_hwnd, unread_count() ? "You've Got Mail!" : "No new mail.", "America Online", MB_OK | MB_ICONINFORMATION);
}

static void start_dial(void) {
    char name[32], loc[64];
    GetWindowTextA(GetDlgItem(g_hwnd, ID_NAME), name, 32);
    if (!valid_name(name)) {
        MessageBoxA(g_hwnd, "Screen names are 3 to 16 characters with no spaces.", APP_TITLE, MB_OK);
        return;
    }
    lstrcpynA(g_name, name, 20);
    GetWindowTextA(GetDlgItem(g_hwnd, ID_LOC), loc, 64);
    g_busy = strstr(loc, "Busy") != NULL;
    g_speaker = (int)SendMessageA(GetDlgItem(g_hwnd, ID_SPEAKER), BM_GETCHECK, 0, 0) == BST_CHECKED;
    g_state = ST_DIAL;
    g_dial_step = 0;
    show_signon(FALSE);
    set_title();
    SetTimer(g_hwnd, ID_TIMER_DIAL, 850, NULL);
    if (g_speaker) {
        Beep(350, 80);
        Beep(440, 80);
    }
    InvalidateRect(g_hwnd, NULL, TRUE);
}

static void sign_off(void) {
    g_state = ST_GOODBYE;
    KillTimer(g_hwnd, ID_TIMER_CHAT);
    KillTimer(g_hwnd, ID_TIMER_CLOCK);
    show_signon(FALSE);
    set_title();
    if (g_speaker) Beep(400, 120);
    InvalidateRect(g_hwnd, NULL, TRUE);
    SetTimer(g_hwnd, ID_TIMER_BYE, 1600, NULL);
}

static void open_channel(const char *title) {
    g_view = VIEW_CHANNEL;
    lstrcpynA(g_channel, title, 64);
    if (!_stricmp(title, "Today's News"))
        lstrcpyA(g_article, "October 1999. Senate debate runs past midnight. Dow holds above 10,600. Hurricane watch on the Outer Banks. NASA slips the shuttle window two days.");
    else if (!_stricmp(title, "Sports"))
        lstrcpyA(g_article, "Yankees take Game 2. NFL Week 5 is on the Grandstand. Serena is in the final. Fantasy desk opens at noon. Keyword: FOOTBALL");
    else if (!_stricmp(title, "Games"))
        lstrcpyA(g_article, "Slingo night. NTN trivia in the lounge. Neverwinter is full; GemStone board is the overflow. This recreation keeps the lobby, not the shard.");
    else if (!_stricmp(title, "Weather"))
        lstrcpyA(g_article, "Vienna, VA. 72 and fair. Wind 6. Tonight 58. Tomorrow 75. Outer Banks under a hurricane watch.");
    else if (!_stricmp(title, "Quotes"))
        lstrcpyA(g_article, "Delayed quotes, 1999 fractions. AOL 92 1/4  +3. YHOO 84 1/2  +1 1/8. AMZN 80 3/8  -2. MSFT 91 1/16  +5/8. Not a broker.");
    else if (!_stricmp(title, "Kids Only"))
        lstrcpyA(g_article, "Homework help from 4 to 6. Rugrats coloring pages as GIF files. Book of the week: Holes. Parental Controls can lock a screen name here.");
    else if (!_stricmp(title, "You've Got Pictures"))
        lstrcpyA(g_article, "Roll 2148, beach, two frames backlit. Roll 2201, birthday, candles slightly blurry. The Kodak drop, simulated.");
    else if (!_stricmp(title, "Personal Finance"))
        lstrcpyA(g_article, "AOL up 3 on heavier volume. Message boards are glowing. This is not advice and these prices are not live.");
    else if (!_stricmp(title, "Internet"))
        lstrcpyA(g_article, "The AOL browser would have fetched this through the proxy. This window stays on your PC. No site is contacted.");
    else if (!_stricmp(title, "Member Services"))
        lstrcpyA(g_article, "Keywords: mail, chat, news, sports, games, weather, stocks, kids, finance, pictures, help, internet, buddy. Sign Off hangs up the simulated call.");
    else
        wsprintfA(g_article, "%s is open. Pick a folder from the list the real channel would have shown. Content here is a local stand-in.", title);
    layout_online();
    InvalidateRect(g_hwnd, NULL, TRUE);
}

static void go_keyword(void) {
    char k[64];
    const char *title;
    GetWindowTextA(GetDlgItem(g_hwnd, ID_KEYWORD), k, 64);
    title = keyword_title(k);
    if (!title) {
        MessageBoxA(g_hwnd, "No keyword. Try mail, chat, news, sports, games, weather, stocks.", APP_TITLE, MB_OK);
        return;
    }
    if (!_stricmp(k, "mail")) {
        g_view = VIEW_MAIL;
        lstrcpyA(g_channel, "Mailbox");
        fill_mail();
        layout_online();
        InvalidateRect(g_hwnd, NULL, TRUE);
        return;
    }
    if (!_stricmp(k, "chat") || !_stricmp(k, "people")) {
        g_view = VIEW_CHAT;
        g_room = 0;
        lstrcpyA(g_channel, "People Connection - Lobby");
        SendMessageA(GetDlgItem(g_hwnd, ID_CHATLOG), LB_RESETCONTENT, 0, 0);
        SendMessageA(GetDlgItem(g_hwnd, ID_CHATLOG), LB_ADDSTRING, 0, (LPARAM)"You have entered the Lobby.");
        SetTimer(g_hwnd, ID_TIMER_CHAT, 2800, NULL);
        layout_online();
        InvalidateRect(g_hwnd, NULL, TRUE);
        return;
    }
    open_channel(title);
}

static void send_chat(void) {
    char text[200], line[240];
    GetWindowTextA(GetDlgItem(g_hwnd, ID_CHATIN), text, 200);
    if (!text[0]) return;
    wsprintfA(line, "%s:  %s", g_name, text);
    SendMessageA(GetDlgItem(g_hwnd, ID_CHATLOG), LB_ADDSTRING, 0, (LPARAM)line);
    SetWindowTextA(GetDlgItem(g_hwnd, ID_CHATIN), "");
}

static void send_compose(void) {
    char to[32], sub[80], body[400];
    if (g_mail_n >= 30) return;
    GetWindowTextA(GetDlgItem(g_hwnd, ID_TO), to, 32);
    GetWindowTextA(GetDlgItem(g_hwnd, ID_SUBJ), sub, 80);
    GetWindowTextA(GetDlgItem(g_hwnd, ID_BODY), body, 400);
    lstrcpynA(g_mail[g_mail_n].from, g_name, 32);
    lstrcpynA(g_mail[g_mail_n].to, to[0] ? to : "Friend", 32);
    lstrcpynA(g_mail[g_mail_n].subject, sub[0] ? sub : "(no subject)", 80);
    lstrcpynA(g_mail[g_mail_n].body, body, 400);
    lstrcpyA(g_mail[g_mail_n].when, "Just now");
    g_mail[g_mail_n].unread = 0;
    g_mail[g_mail_n].sent = 1;
    g_mail_n++;
    if (g_mail_n < 32) {
        lstrcpynA(g_mail[g_mail_n].from, to[0] ? to : "Friend", 32);
        lstrcpynA(g_mail[g_mail_n].to, g_name, 32);
        wsprintfA(g_mail[g_mail_n].subject, "Re: %s", sub[0] ? sub : "(no subject)");
        lstrcpyA(g_mail[g_mail_n].body, "got it. signing on was the usual circus.");
        lstrcpyA(g_mail[g_mail_n].when, "Just now");
        g_mail[g_mail_n].unread = 1;
        g_mail[g_mail_n].sent = 0;
        g_mail_n++;
    }
    MessageBoxA(g_hwnd, "Mail sent. A reply is in the mailbox.", APP_TITLE, MB_OK);
    g_view = VIEW_MAIL;
    fill_mail();
    layout_online();
    InvalidateRect(g_hwnd, NULL, TRUE);
}

static void paint(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC dc = BeginPaint(hwnd, &ps);
    RECT rc;
    char line[160];
    GetClientRect(hwnd, &rc);
    FillRect(dc, &rc, g_win);
    SetBkMode(dc, TRANSPARENT);
    if (g_state == ST_GOODBYE) {
        RECT bar = {0, 0, rc.right, rc.bottom};
        FillRect(dc, &bar, g_navy);
        SetTextColor(dc, RGB(255, 255, 255));
        SelectObject(dc, g_font_big);
        TextOutA(dc, 40, 80, "Goodbye", 7);
        SelectObject(dc, g_font);
        TextOutA(dc, 40, 120, "from America Online", 19);
        EndPaint(hwnd, &ps);
        return;
    }
    {
        RECT bar = {0, 0, rc.right, 28};
        FillRect(dc, &bar, g_navy);
        SetTextColor(dc, RGB(255, 255, 255));
        SelectObject(dc, g_font);
        TextOutA(dc, 8, 6, "America Online", 14);
        draw_logo(dc, rc.right - 36, 2, 22);
    }
    if (g_state == ST_SIGNON) {
        RECT card = { rc.right/2 - 210, 70, rc.right/2 + 210, 430 };
        FillRect(dc, &card, g_white);
        FrameRect(dc, &card, g_navy);
        draw_logo(dc, rc.right/2 - 150, 86, 64);
        SetTextColor(dc, RGB(22, 58, 114));
        SelectObject(dc, g_font);
        TextOutA(dc, rc.right/2 - 60, 96, "AMERICA", 7);
        SelectObject(dc, g_font_script);
        TextOutA(dc, rc.right/2 - 60, 114, "Online", 6);
        SelectObject(dc, g_font);
        SetTextColor(dc, RGB(0, 0, 0));
        TextOutA(dc, rc.right/2 - 180, 168, "Select Screen Name", 18);
        TextOutA(dc, rc.right/2 - 180, 214, "Enter Password", 14);
        TextOutA(dc, rc.right/2 - 180, 260, "Select Location", 15);
        SetTextColor(dc, RGB(80, 80, 80));
        TextOutA(dc, rc.right/2 - 150, 400, "America Online 5.0  -  native window", 36);
    } else if (g_state == ST_DIAL) {
        RECT card = { rc.right/2 - 250, 70, rc.right/2 + 250, 360 };
        RECT p1 = { rc.right/2 - 220, 160, rc.right/2 - 70, 250 };
        RECT p2 = { rc.right/2 - 70, 160, rc.right/2 + 70, 250 };
        RECT p3 = { rc.right/2 + 70, 160, rc.right/2 + 220, 250 };
        int slot = g_dial_step < 2 ? 0 : g_dial_step < 5 ? 1 : 2;
        FillRect(dc, &card, g_white);
        FrameRect(dc, &card, g_navy);
        draw_logo(dc, rc.right/2 - 40, 84, 48);
        FillRect(dc, &p1, g_lavender); FrameRect(dc, &p1, g_navy);
        FillRect(dc, &p2, g_lavender); FrameRect(dc, &p2, g_navy);
        FillRect(dc, &p3, g_lavender); FrameRect(dc, &p3, g_navy);
        draw_logo(dc, (slot == 0 ? p1.left : slot == 1 ? p2.left : p3.left) + 28, 178, 40);
        SetTextColor(dc, RGB(0, 0, 0));
        SelectObject(dc, g_font);
        TextOutA(dc, rc.right/2 - 80, 268, DIAL_STEPS[g_dial_step < DIAL_N ? g_dial_step : DIAL_N - 1],
                 lstrlenA(DIAL_STEPS[g_dial_step < DIAL_N ? g_dial_step : DIAL_N - 1]));
        TextOutA(dc, rc.right/2 - 200, 300, "Step follows the old client: dial, connect, network attention, password.", 72);
    } else {
        RECT side = { 0, 28, 150, rc.bottom - 22 };
        FillRect(dc, &side, g_navy);
        SetTextColor(dc, RGB(255, 255, 255));
        SelectObject(dc, g_font);
        TextOutA(dc, 12, 40, g_name, lstrlenA(g_name));
        TextOutA(dc, 12, 62, unread_count() ? "You Have Mail" : "No New Mail", unread_count() ? 13 : 11);
        SetTextColor(dc, RGB(0, 0, 40));
        SelectObject(dc, g_font_big);
        TextOutA(dc, 166, 40, g_channel, lstrlenA(g_channel));
        SelectObject(dc, g_font);
        SetTextColor(dc, RGB(20, 20, 20));
        if (g_view == VIEW_WELCOME || g_view == VIEW_CHANNEL) {
            RECT text = { 166, 78, rc.right - 200, rc.bottom - 30 };
            DrawTextA(dc, g_article, -1, &text, DT_WORDBREAK);
        }
        if (g_view == VIEW_COMPOSE) {
            TextOutA(dc, 166, 78, "To", 2);
            TextOutA(dc, 166, 106, "Subject", 7);
        }
        SetTextColor(dc, RGB(0, 0, 0));
        wsprintfA(line, "Online %02d:%02d    %s    Simulation - not connected to AOL", g_seconds / 60, g_seconds % 60, g_speed);
        TextOutA(dc, 8, rc.bottom - 18, line, lstrlenA(line));
    }
    EndPaint(hwnd, &ps);
}

static void on_command(int id) {
    if (id == ID_SIGNON) start_dial();
    else if (id == ID_SETUP) MessageBoxA(g_hwnd, "Modem: Sportster 56K (simulated)\nInit: AT&F1E0Q0V1\nAccess numbers are fictional 555 numbers.\nThis program never opens a COM port.", "AOL Setup", MB_OK);
    else if (id == ID_CANCELDIAL) { KillTimer(g_hwnd, ID_TIMER_DIAL); g_state = ST_SIGNON; show_signon(TRUE); set_title(); InvalidateRect(g_hwnd, NULL, TRUE); }
    else if (id == ID_GO) go_keyword();
    else if (id == ID_CHATSEND) send_chat();
    else if (id == ID_SENDMAIL) send_compose();
    else if (id == ID_READ) {
        HWND lb = GetDlgItem(g_hwnd, ID_MAIL);
        int sel = (int)SendMessageA(lb, LB_GETCURSEL, 0, 0);
        int idx;
        if (sel < 0) return;
        idx = (int)SendMessageA(lb, LB_GETITEMDATA, sel, 0);
        if (idx >= 0 && idx < g_mail_n) {
            g_mail[idx].unread = 0;
            MessageBoxA(g_hwnd, g_mail[idx].body, g_mail[idx].subject, MB_OK);
            fill_mail();
            InvalidateRect(g_hwnd, NULL, TRUE);
        }
    }
    else if (id == ID_WRITE || id == M_COMPOSE) {
        if (g_state != ST_ONLINE) return;
        g_view = VIEW_COMPOSE;
        lstrcpyA(g_channel, "Write Mail");
        layout_online();
        InvalidateRect(g_hwnd, NULL, TRUE);
    }
    else if (id == ID_DELETE) {
        HWND lb = GetDlgItem(g_hwnd, ID_MAIL);
        int sel = (int)SendMessageA(lb, LB_GETCURSEL, 0, 0);
        int idx, i;
        if (sel < 0) return;
        idx = (int)SendMessageA(lb, LB_GETITEMDATA, sel, 0);
        for (i = idx; i < g_mail_n - 1; i++) g_mail[i] = g_mail[i + 1];
        g_mail_n--;
        fill_mail();
    }
    else if (id == M_EXIT) DestroyWindow(g_hwnd);
    else if (id == M_SIGNOFF) { if (g_state == ST_ONLINE) sign_off(); }
    else if (id == M_ABOUT) MessageBoxA(g_hwnd, "America Online 5.0 recreation.\nNative Win32 window. Not a browser.\nNot affiliated with AOL. No modem is dialed.", "About America Online", MB_OK);
    else if (g_state != ST_ONLINE) return;
    else if (id == M_WELCOME) { g_view = VIEW_WELCOME; lstrcpyA(g_channel, "Welcome"); lstrcpyA(g_article, "Welcome. Use the menu or the Keyword box. Mail, People Connection, channels, and the buddy list are in this window."); layout_online(); InvalidateRect(g_hwnd, NULL, TRUE); }
    else if (id == M_MAIL || id == M_SENT) { g_view = VIEW_MAIL; lstrcpyA(g_channel, "Mailbox"); fill_mail(); layout_online(); InvalidateRect(g_hwnd, NULL, TRUE); }
    else if (id == M_PEOPLE) { SetWindowTextA(GetDlgItem(g_hwnd, ID_KEYWORD), "chat"); go_keyword(); }
    else if (id == M_BUDDY || id == M_IM) { g_view = VIEW_BUDDY; lstrcpyA(g_channel, "Buddy List"); lstrcpyA(g_article, "Double-click a buddy name in the list. Instant messages in this recreation answer from the same room of screen names."); fill_buddy(); layout_online(); InvalidateRect(g_hwnd, NULL, TRUE); }
    else if (id == M_CHANNELS) open_channel("Channels");
    else if (id == M_NEWS) open_channel("Today's News");
    else if (id == M_SPORTS) open_channel("Sports");
    else if (id == M_GAMES) open_channel("Games");
    else if (id == M_WEATHER) open_channel("Weather");
    else if (id == M_STOCKS) open_channel("Quotes");
    else if (id == M_KIDS) open_channel("Kids Only");
    else if (id == M_PICTURES) open_channel("You've Got Pictures");
    else if (id == M_INTERNET) open_channel("Internet");
    else if (id == M_HELP) open_channel("Member Services");
}

static BOOL CALLBACK SetFontProc(HWND child, LPARAM lp) {
    (void)lp;
    SendMessageA(child, WM_SETFONT, (WPARAM)g_font, TRUE);
    return TRUE;
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        int x = 280;
        CreateWindowA("EDIT", "SteveCaseFan", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL, x, 188, 240, 22, hwnd, (HMENU)ID_NAME, NULL, NULL);
        CreateWindowA("EDIT", "", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_PASSWORD | ES_AUTOHSCROLL, x, 234, 240, 22, hwnd, (HMENU)ID_PASS, NULL, NULL);
        CreateWindowA("COMBOBOX", "", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST, x, 280, 240, 120, hwnd, (HMENU)ID_LOC, NULL, NULL);
        SendMessageA(GetDlgItem(hwnd, ID_LOC), CB_ADDSTRING, 0, (LPARAM)"Home - (703) 555-0142");
        SendMessageA(GetDlgItem(hwnd, ID_LOC), CB_ADDSTRING, 0, (LPARAM)"Office - dial 9, (212) 555-0199");
        SendMessageA(GetDlgItem(hwnd, ID_LOC), CB_ADDSTRING, 0, (LPARAM)"Hotel - (312) 555-0177");
        SendMessageA(GetDlgItem(hwnd, ID_LOC), CB_ADDSTRING, 0, (LPARAM)"Busy exchange - (202) 555-0100");
        SendMessageA(GetDlgItem(hwnd, ID_LOC), CB_SETCURSEL, 0, 0);
        CreateWindowA("BUTTON", "Modem speaker on", WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, x, 312, 180, 20, hwnd, (HMENU)ID_SPEAKER, NULL, NULL);
        SendMessageA(GetDlgItem(hwnd, ID_SPEAKER), BM_SETCHECK, BST_CHECKED, 0);
        CreateWindowA("BUTTON", "Setup", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON, x, 348, 90, 26, hwnd, (HMENU)ID_SETUP, NULL, NULL);
        CreateWindowA("BUTTON", "Sign On", WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON, x + 150, 348, 90, 26, hwnd, (HMENU)ID_SIGNON, NULL, NULL);
        CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 0, 0, 10, 10, hwnd, (HMENU)ID_KEYWORD, NULL, NULL);
        CreateWindowA("BUTTON", "Go", WS_CHILD | BS_PUSHBUTTON, 0, 0, 10, 10, hwnd, (HMENU)ID_GO, NULL, NULL);
        CreateWindowA("LISTBOX", "", WS_CHILD | WS_BORDER | LBS_NOTIFY | WS_VSCROLL, 0, 0, 10, 10, hwnd, (HMENU)ID_MAIL, NULL, NULL);
        CreateWindowA("BUTTON", "Read", WS_CHILD | BS_PUSHBUTTON, 0, 0, 10, 10, hwnd, (HMENU)ID_READ, NULL, NULL);
        CreateWindowA("BUTTON", "Write", WS_CHILD | BS_PUSHBUTTON, 0, 0, 10, 10, hwnd, (HMENU)ID_WRITE, NULL, NULL);
        CreateWindowA("BUTTON", "Delete", WS_CHILD | BS_PUSHBUTTON, 0, 0, 10, 10, hwnd, (HMENU)ID_DELETE, NULL, NULL);
        CreateWindowA("LISTBOX", "", WS_CHILD | WS_BORDER | WS_VSCROLL, 0, 0, 10, 10, hwnd, (HMENU)ID_CHATLOG, NULL, NULL);
        CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER | ES_AUTOHSCROLL, 0, 0, 10, 10, hwnd, (HMENU)ID_CHATIN, NULL, NULL);
        CreateWindowA("BUTTON", "Send", WS_CHILD | BS_PUSHBUTTON, 0, 0, 10, 10, hwnd, (HMENU)ID_CHATSEND, NULL, NULL);
        CreateWindowA("LISTBOX", "", WS_CHILD | WS_BORDER | LBS_NOTIFY | WS_VSCROLL, 0, 0, 10, 10, hwnd, (HMENU)ID_BUDDY, NULL, NULL);
        CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER, 0, 0, 10, 10, hwnd, (HMENU)ID_TO, NULL, NULL);
        CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER, 0, 0, 10, 10, hwnd, (HMENU)ID_SUBJ, NULL, NULL);
        CreateWindowA("EDIT", "", WS_CHILD | WS_BORDER | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL, 0, 0, 10, 10, hwnd, (HMENU)ID_BODY, NULL, NULL);
        CreateWindowA("BUTTON", "Send Now", WS_CHILD | BS_PUSHBUTTON, 0, 0, 10, 10, hwnd, (HMENU)ID_SENDMAIL, NULL, NULL);
        EnumChildWindows(hwnd, SetFontProc, 0);
        return 0;
    }
    case WM_COMMAND:
        on_command(LOWORD(wp));
        if (LOWORD(wp) == ID_BUDDY && HIWORD(wp) == LBN_DBLCLK && g_state == ST_ONLINE) {
            MessageBoxA(hwnd, "Instant message opened.\nBuddy: online\nReply: brb phone", "Instant Message", MB_OK);
        }
        return 0;
    case WM_TIMER:
        if (wp == ID_TIMER_DIAL) {
            g_dial_step++;
            if (g_speaker) Beep(800 + g_dial_step * 40, 40);
            if (g_busy && g_dial_step == 3) {
                KillTimer(hwnd, ID_TIMER_DIAL);
                if (g_speaker) { Beep(480, 150); Beep(620, 150); }
                MessageBoxA(hwnd, "The access number is busy. Choose another location.", APP_TITLE, MB_OK);
                g_state = ST_SIGNON;
                show_signon(TRUE);
                set_title();
            } else if (g_dial_step >= DIAL_N) {
                KillTimer(hwnd, ID_TIMER_DIAL);
                enter_online();
            }
            InvalidateRect(hwnd, NULL, TRUE);
        } else if (wp == ID_TIMER_CHAT && g_view == VIEW_CHAT) {
            char line[160];
            wsprintfA(line, "%s:  %s", CHATTERS[g_seconds % 7], LINES[g_seconds % 9]);
            SendMessageA(GetDlgItem(hwnd, ID_CHATLOG), LB_ADDSTRING, 0, (LPARAM)line);
        } else if (wp == ID_TIMER_BYE) {
            KillTimer(hwnd, ID_TIMER_BYE);
            g_state = ST_SIGNON;
            g_speed[0] = 0;
            show_signon(TRUE);
            set_title();
            InvalidateRect(hwnd, NULL, TRUE);
        } else if (wp == ID_TIMER_CLOCK && g_state == ST_ONLINE) {
            g_seconds++;
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;
    case WM_SIZE:
        if (g_state == ST_ONLINE) layout_online();
        else {
            RECT rc; GetClientRect(hwnd, &rc);
            int x = rc.right/2 - 180;
            MoveWindow(GetDlgItem(hwnd, ID_NAME), x, 188, 240, 22, TRUE);
            MoveWindow(GetDlgItem(hwnd, ID_PASS), x, 234, 240, 22, TRUE);
            MoveWindow(GetDlgItem(hwnd, ID_LOC), x, 280, 240, 120, TRUE);
            MoveWindow(GetDlgItem(hwnd, ID_SPEAKER), x, 312, 180, 20, TRUE);
            MoveWindow(GetDlgItem(hwnd, ID_SETUP), x, 348, 90, 26, TRUE);
            MoveWindow(GetDlgItem(hwnd, ID_SIGNON), x + 150, 348, 90, 26, TRUE);
        }
        return 0;
    case WM_PAINT:
        paint(hwnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcA(hwnd, msg, wp, lp);
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show) {
    WNDCLASSA wc;
    MSG msg;
    HMENU bar, file, go, mail, members, help;
    (void)prev; (void)show;
    if (cmd && strstr(cmd, "selftest")) {
        char report[1400];
        HANDLE f;
        DWORD n;
        int ok = selftest(report, 1400);
        f = CreateFileA("AmericaOnline-selftest.txt", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (f != INVALID_HANDLE_VALUE) {
            WriteFile(f, report, lstrlenA(report), &n, NULL);
            CloseHandle(f);
        }
        MessageBoxA(NULL, report, ok ? "SELF-TEST OK" : "SELF-TEST FAILED", MB_OK);
        return ok ? 0 : 1;
    }
    seed_mail();
    g_font = CreateFontA(16, 0, 0, 0, FW_NORMAL, 0, 0, 0, ANSI_CHARSET, 0, 0, 0, 0, "Tahoma");
    g_font_big = CreateFontA(28, 0, 0, 0, FW_BOLD, 0, 0, 0, ANSI_CHARSET, 0, 0, 0, 0, "Tahoma");
    g_font_script = CreateFontA(28, 0, 0, 0, FW_NORMAL, 1, 0, 0, ANSI_CHARSET, 0, 0, 0, 0, "Georgia");
    g_navy = CreateSolidBrush(RGB(0, 0, 128));
    g_lavender = CreateSolidBrush(RGB(201, 198, 239));
    g_win = CreateSolidBrush(RGB(212, 208, 200));
    g_white = CreateSolidBrush(RGB(251, 250, 246));
    g_gold = CreateSolidBrush(RGB(240, 196, 25));
    ZeroMemory(&wc, sizeof wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.lpszClassName = "AOL5Window";
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = g_win;
    wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    RegisterClassA(&wc);
    bar = CreateMenu();
    file = CreateMenu();
    go = CreateMenu();
    mail = CreateMenu();
    members = CreateMenu();
    help = CreateMenu();
    AppendMenuA(file, MF_STRING, M_SIGNOFF, "Sign Off");
    AppendMenuA(file, MF_STRING, M_EXIT, "Exit");
    AppendMenuA(go, MF_STRING, M_WELCOME, "Welcome");
    AppendMenuA(go, MF_STRING, M_CHANNELS, "Channels");
    AppendMenuA(go, MF_STRING, M_NEWS, "Today's News");
    AppendMenuA(go, MF_STRING, M_SPORTS, "Sports");
    AppendMenuA(go, MF_STRING, M_GAMES, "Games");
    AppendMenuA(go, MF_STRING, M_WEATHER, "Weather");
    AppendMenuA(go, MF_STRING, M_STOCKS, "Quotes");
    AppendMenuA(go, MF_STRING, M_KIDS, "Kids Only");
    AppendMenuA(go, MF_STRING, M_PICTURES, "You've Got Pictures");
    AppendMenuA(go, MF_STRING, M_INTERNET, "Internet");
    AppendMenuA(go, MF_STRING, M_PEOPLE, "People Connection");
    AppendMenuA(mail, MF_STRING, M_MAIL, "Read Mail");
    AppendMenuA(mail, MF_STRING, M_COMPOSE, "Write Mail");
    AppendMenuA(mail, MF_STRING, M_SENT, "Sent Mail");
    AppendMenuA(members, MF_STRING, M_BUDDY, "Buddy List");
    AppendMenuA(members, MF_STRING, M_IM, "Send Instant Message");
    AppendMenuA(help, MF_STRING, M_HELP, "Member Services");
    AppendMenuA(help, MF_STRING, M_ABOUT, "About America Online");
    AppendMenuA(bar, MF_POPUP, (UINT_PTR)file, "File");
    AppendMenuA(bar, MF_POPUP, (UINT_PTR)go, "Go To");
    AppendMenuA(bar, MF_POPUP, (UINT_PTR)mail, "Mail");
    AppendMenuA(bar, MF_POPUP, (UINT_PTR)members, "Members");
    AppendMenuA(bar, MF_POPUP, (UINT_PTR)help, "Help");
    AppendMenuA(bar, MF_STRING, M_SIGNOFF, "Sign Off");
    g_hwnd = CreateWindowA("AOL5Window", "America Online - Sign On",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, 960, 640,
        NULL, bar, inst, NULL);
    while (GetMessageA(&msg, NULL, 0, 0)) {
        if (msg.message == WM_KEYDOWN && msg.wParam == VK_RETURN && g_state == ST_ONLINE && GetFocus() == GetDlgItem(g_hwnd, ID_CHATIN))
            send_chat();
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
    return (int)msg.wParam;
}
