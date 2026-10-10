# thimble

A Windows window that thinks it is 1999, a host that keeps the screen names, and a pool that will take a coin repo if you paste one.

Show a friend the page: https://5mil.github.io/thimble/

That page dials, plays the modem, and talks back. It does not share a room with you. The shared host is this branch.

## Modules, house, merge, payout

`pools.cfg` is the module list. Each line that is on gets its own listener. Two modules on means two ports, two jobs, two totals. Turning one off leaves the others.

House is a worker named `house`. It only runs if the settings window saved `#house 1` and a chain source is connected. The bonus percent on the module is taken from house shares, not printed.

Merge is stored per module (`Litecoin` can say `Dogecoin`). The report shows the child. A second chain source for that child is the next wire. Until then the share is still the parent’s share.

`payouts.cfg` is the ledger: screen name and balance. A send happens only after a balance clears 1000. The file is the record. It is not a broadcast.

Set one of these before the host starts. The report’s first line is the chain.

- `AOL_UPSTREAM=host:3333` — the host mirrors a real pool. Jobs are that pool’s jobs. Shares are forwarded. No chain download.
- `AOL_RPC=http://user:pass@127.0.0.1:8332` — the host asks a node. State is `syncing`, `headers`, `pruned`, or `ready`. Height, peers, and IBD are on the line. A pruned node (`bitcoind -prune=550`) is enough.
- Neither set — the line says `no node`.

`AOL_WALLET` is the coinbase address used when a template is built. Balances on the report are share-difficulty units, not yet a payout run.

The page and the window stay sardonic. The host underneath is the thing you leave running.

Saves of members and mail go to `aol.db.tmp` and replace `aol.db` only after the write finishes. Party shares do the same with `party.db`. A crash mid-save does not leave a half file as the only copy.

Sessions die after seven days without use. `/api/health` returns users, sessions, messages, accepted shares, and worker count. Set `AOL_ADMIN` before any coin fetch. Repos stay limited to GitHub and GitLab HTTPS.

If `pools.cfg` exists, only modules marked on open a stratum port. With no file, or with every module off, all six ports open. The report window and the settings window are separate. Settings reload from `pools.cfg` on the next start.

`AmericaOnlineServer.exe` is the console. It starts the sign-on host on 8080 and the pool on 3333 through 3338. The menu in that window is `1` host, `2` pool status, `3` fetch a coin repo, `4` quit. Set `AOL_ADMIN` before you use admin or fetch.

`AmericaOnline.exe` is the window. Sign up, sign on, send in a room, read mail, and press Start rig. The rig box is the worker name, `Kitchen.rig1`. The port box is 8080 for sign-on and 3333 for the rig.

Both files are in this branch. Rebuild them with:

```
zig build-exe src/server.zig -target x86_64-windows-gnu -OReleaseSafe -lc -femit-bin=AmericaOnlineServer.exe
zig build-exe src/client.zig -target x86_64-windows-gnu -OReleaseSafe -lwinhttp --subsystem windows -femit-bin=AmericaOnline.exe
```

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

Set `AOL_ADMIN` to at least 8 characters before you start the host. There is no default token. The repo must be `https://github.com/` or `https://gitlab.com/`, with no spaces and no `..`. The host clones it into `coin-src/` and writes `coin.cfg`. The pool advertises that name. It does not compile the validator. That command belongs to the coin.

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
