# America Online, one host

This branch is a working sign-on, not a sketch. One process keeps the members.

## Run the server

```
python server.py
```

It listens on port 8080 and writes `aol.db` beside itself. Open http://127.0.0.1:8080 to sign up in the browser. Screen names are saved. Passwords are stored as a hash, not as text.

Rooms: Lobby, Thirtysomething, Computer Help, Sports Bar, New Member Lounge. Chat lines and mail stay in the database after you close the window.

## Windows client

`AmericaOnline.exe` is the window. Put the server machine in Host. Use `127.0.0.1` on the same PC, or that PC's address from another one. Sign Up once, then Sign On. Send talks to whoever is in the same room on that server. You've Got Mail reads the inbox.

`Launch America Online.bat` starts the window.

The page and the program use the same accounts. A name taken in the browser is taken in the program.
