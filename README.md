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

## Mining pool

The host speaks Stratum V1, the same handshake Magister and gitmine use: `mining.subscribe`, `mining.authorize`, `mining.notify`, `mining.submit`. ASIC firmware and GPU miners that speak that handshake can point at it. The password can say `asic` or `gpu`; the worker name is `screen.rig`.

Ports, one algorithm each:

- 3333 sha256d, the ASIC Bitcoin-style port
- 3334 scrypt
- 3335 ethash, GPU
- 3336 kawpow, GPU
- 3337 randomx, CPU
- 3338 yescrypt, the Yes ZigR32 algorithm name

`GET /api/pool` lists workers, algorithm, and device class.

The miner counts CPUs, looks for `/dev/nvidia0`, `/dev/dri/card0`, and `/dev/ttyUSB0`, then still obeys the flags:

```
./aol-miner --host 127.0.0.1 --port 3335 --worker SteveCaseFan.rig1 --threads 4 --device gpu
```

## Coin codebase

The pool can download a coin tree and advertise it. Orthal and agave-hybrid are the known names. Any git URL works.

```
zig build-exe src/coin.zig -OReleaseSafe -femit-bin=aol-coin
./aol-coin list
./aol-coin fetch orthal
```

That clones into `coin-src/` and writes `coin.cfg`. The pool reads the name on `/api/pool`. Building the validator is the coin's own command, printed after the fetch. This host does not vendor the chain.

An admin can do the same from the host. Open `http://127.0.0.1:8080/admin`, paste an `https://` repo, and the token. The token is `lobby` unless `AOL_ADMIN` is set. The host clones the tree into `coin-src/` and the pool advertises that coin.
