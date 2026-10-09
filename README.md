# thimble

A Windows window that thinks it is 1999, a host that keeps the screen names, and a pool that will take a coin repo if you paste one.

Show a friend the page: https://5mil.github.io/thimble/

That page dials, plays the modem, and talks back. It does not share a room with you. The shared host is this branch.

## Host

```
zig build run
```

Or:

```
zig build-exe src/server.zig -OReleaseSafe -femit-bin=aol-server
./aol-server
```

Port 8080. Members stay in `aol.db`. Passwords are a PBKDF2 hash. Open http://127.0.0.1:8080 to sign up. Screen names are 3 to 16 letters and numbers, starting with a letter.

`./aol-server --selftest` checks signup, a lobby line, and mail.

## Windows window

`AmericaOnline.exe` is built from `src/client.zig`. Host `127.0.0.1`, port `8080`, on the same machine. Sign Up once, then Sign On. Send writes the room. You've Got Mail reads the inbox.

```
zig build-exe src/client.zig -target x86_64-windows-gnu -OReleaseSafe -lwinhttp --subsystem windows -femit-bin=AmericaOnline.exe
```

The page and the program use the same accounts on that host.

## Pool

The host speaks Stratum: `mining.subscribe`, `mining.authorize`, `mining.notify`, `mining.submit`. Worker name is `screen.rig`. Put `asic` or `gpu` in the password or the device flag.

- 3333 sha256d
- 3334 scrypt
- 3335 ethash
- 3336 kawpow
- 3337 randomx
- 3338 yescrypt

`GET /api/pool` lists workers, algorithm, device, and the coin name.

```
zig build-exe src/miner.zig -OReleaseSafe -femit-bin=aol-miner
./aol-miner --host 127.0.0.1 --port 3335 --worker SteveCaseFan.rig1 --threads 4 --device gpu
```

Leave `--threads` and `--device` off and it counts CPUs and looks for `/dev/nvidia0`, `/dev/dri/card0`, and `/dev/ttyUSB0`.

## Coin

Admin page: http://127.0.0.1:8080/admin

Token is `lobby` unless `AOL_ADMIN` is set. Repo must be `https://`. The host clones it into `coin-src/` and writes `coin.cfg`. The pool advertises that name. It does not compile the validator. That command belongs to the coin.

The same fetch from a shell:

```
zig build-exe src/coin.zig -OReleaseSafe -femit-bin=aol-coin
./aol-coin list
./aol-coin fetch orthal
./aol-coin fetch https://github.com/5mil/agave-hybrid.git
```

Known names: orthal, agave-hybrid.

## Party

The group is the text before the dot in the worker name. `Kitchen.rig1` and `Kitchen.asic` share one party. A name with no dot joins `lobby`. Shares are written to `party.db` and loaded again on the next start, so a restart does not clear the night. `/api/pool` lists each party total next to the workers. Reconnecting the same worker updates the device and does not open a second seat.
