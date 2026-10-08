# America Online, written in Zig

The host and the Windows window are Zig. The page is still HTML, because a browser has to draw it.

## Run the host

```
zig build run
```

Or build it once:

```
zig build-exe src/server.zig -OReleaseSafe -femit-bin=aol-server
./aol-server
```

It listens on port 8080 and keeps members in `aol.db` next to the program. Open http://127.0.0.1:8080 to sign up. Screen names are stored. Passwords are stored as a PBKDF2 hash.

`zig build-exe src/server.zig` then `./server --selftest` checks signup, a lobby line, and mail.

## Windows client

`AmericaOnline.exe` is built from `src/client.zig`. Put the host machine in Host. Use `127.0.0.1` and `8080` on the same PC. Sign Up once, then Sign On. Send writes into the room. You've Got Mail reads the inbox.

Rebuild the window from Linux or macOS with:

```
zig build-exe src/client.zig -target x86_64-windows-gnu -OReleaseSafe -lwinhttp --subsystem windows -femit-bin=AmericaOnline.exe
```

The page and the program use the same accounts on that host.
