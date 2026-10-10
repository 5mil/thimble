# thimble

A window that thinks it is 1999, a host that keeps the screen names, and a pool that will take a chain source if you give it one.

The page: https://5mil.github.io/thimble/  
The host: https://github.com/5mil/thimble/tree/lobby

The page dials. The host is the thing you leave running.

## What you are running

| Program | Where | What it does |
|---|---|---|
| `aol-server` / `AmericaOnlineServer.exe` | The machine you leave on | Sign-on on 8080. Pool on 3333–3338. Report window on Windows. |
| `AmericaOnline.exe` | A Windows machine | Sign up, sign on, chat, mail, Start rig. |
| `aol-miner` | Linux or Windows | A worker that connects to a pool port. |
| Browser | Anywhere | http://HOST:8080 for sign-on. http://HOST:8080/admin for a coin fetch. |

Files the host writes next to itself: `aol.db` (members, mail), `party.db` (shares), `pools.cfg` (modules), `payouts.cfg` (balances), `coin.cfg` (last fetched coin).

## Get Zig

Zig 0.14.1. https://ziglang.org/download/

Check with `zig version`.

## Windows

### Server

Download `AmericaOnlineServer.exe` from the `lobby` branch, or build it.

Build, from a checkout, with Zig on PATH:

```
zig build-exe src/server.zig -target x86_64-windows-gnu -OReleaseSafe -lc -luser32 -lgdi32 --subsystem windows -femit-bin=AmericaOnlineServer.exe
```

Set the variables, then start it. In `cmd`:

```
set AOL_ADMIN=choose-eight-or-more
set AOL_UPSTREAM=pool.example.com:3333
AmericaOnlineServer.exe
```

In PowerShell:

```
$env:AOL_ADMIN = "choose-eight-or-more"
$env:AOL_UPSTREAM = "pool.example.com:3333"
.\AmericaOnlineServer.exe
```

The window that opens is the report. Pool → Settings is the module list. Settings write `pools.cfg` and reload on the next start.

Firewall: allow inbound TCP 8080 (sign-on) and 3333–3338 (pool) if friends connect from other machines.

### Client

```
zig build-exe src/client.zig -target x86_64-windows-gnu -OReleaseSafe -lwinhttp --subsystem windows -femit-bin=AmericaOnline.exe
```

Run `AmericaOnline.exe`. Host box is the server machine (`127.0.0.1` if it is this PC). Port box is `8080`. Sign Up once, then Sign On. Start rig uses the worker name (`Kitchen.rig1`) and talks to the pool port for that coin (3333 for Bitcoin).

## Linux

One set of commands. The package line is the only part that changes.

### Debian, Ubuntu, Mint, Pop

```
sudo apt update
sudo apt install -y git build-essential
```

Install Zig from ziglang.org (the distro package is often too old). Then:

```
git clone https://github.com/5mil/thimble.git
cd thimble
git checkout lobby
zig build-exe src/server.zig -OReleaseSafe -lc -femit-bin=aol-server
export AOL_ADMIN=choose-eight-or-more
export AOL_UPSTREAM=pool.example.com:3333
./aol-server
```

Open http://127.0.0.1:8080

Leave it up with systemd. `/etc/systemd/system/thimble.service`:

```
[Unit]
Description=thimble host
After=network.target

[Service]
WorkingDirectory=/opt/thimble
Environment=AOL_ADMIN=choose-eight-or-more
Environment=AOL_UPSTREAM=pool.example.com:3333
ExecStart=/opt/thimble/aol-server
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```
sudo systemctl enable --now thimble
```

### Fedora, RHEL, CentOS Stream

```
sudo dnf install -y git gcc
```

Zig from ziglang.org. Same clone, build, and `export` lines as Debian. systemd unit is the same.

### Arch, Manjaro, Endeavour

```
sudo pacman -S --needed git base-devel zig
```

Arch’s `zig` is often current. If `zig version` is 0.14 or newer, use it. Same clone and build as Debian. systemd unit is the same.

### openSUSE

```
sudo zypper install -y git gcc
```

Zig from ziglang.org. Same clone and build.

### Alpine

```
apk add git build-base
```

Zig from ziglang.org. Same clone and build. OpenRC instead of systemd: a line in `/etc/init.d` that runs `./aol-server` with the exports.

### Nix

With Nix on any distro:

```
nix-shell -p zig git
git clone https://github.com/5mil/thimble.git
cd thimble && git checkout lobby
zig build-exe src/server.zig -OReleaseSafe -lc -femit-bin=aol-server
export AOL_ADMIN=choose-eight-or-more
./aol-server
```

NixOS, in `configuration.nix` or a module:

```
environment.systemPackages = with pkgs; [ zig git ];
```

Or a shell app:

```
pkgs.writeShellScriptBin "thimble" ''
  export AOL_ADMIN=''${AOL_ADMIN:-choose-eight-or-more}
  export AOL_UPSTREAM=''${AOL_UPSTREAM:-}
  exec /var/lib/thimble/aol-server
''
```

Build the binary once with `zig build-exe` and point the service at it. Nix does not need to package the Zig sources for the host to run.

## Client on Linux

There is no native Linux window. Use the browser.

http://SERVER:8080

Sign up, sign on, pick a room, send. Mail is on the same host.

A Linux worker is `aol-miner`:

```
zig build-exe src/miner.zig -OReleaseSafe -lc -femit-bin=aol-miner
./aol-miner --host 127.0.0.1 --port 3333 --worker Kitchen.rig1 --threads 4 --device cpu
```

Leave `--threads` and `--device` off and it counts CPUs and looks for `/dev/nvidia0`, `/dev/dri/card0`, and `/dev/ttyUSB0`.

## Configuration

Set these in the environment before the host starts.

| Variable | Required | Meaning |
|---|---|---|
| `AOL_ADMIN` | For coin fetch | 8 or more characters. No default. |
| `AOL_UPSTREAM` | One of these two | `host:3333`. Jobs come from that pool. Shares are forwarded. No chain download. |
| `AOL_RPC` | One of these two | `http://user:pass@127.0.0.1:8332`. Asks a node. Pruned (`bitcoind -prune=550`) is enough. |
| `AOL_WALLET` | For a template | Coinbase address. |

Neither upstream nor RPC: the report says `no node`.

`pools.cfg`, written by the settings window or by hand:

```
Bitcoin	sha256d	3333	1	Namecoin	5
Litecoin	scrypt	3334	1	Dogecoin	0
#house	1
#data	all
```

Columns: name, algorithm, port, on (`1`/`0`), merge child, bonus percent. `#house 1` starts the house worker when a chain source is connected. Two lines with `1` are two listeners.

Pool ports:

| Port | Algorithm |
|---|---|
| 3333 | sha256d |
| 3334 | scrypt |
| 3335 | ethash |
| 3336 | kawpow |
| 3337 | randomx |
| 3338 | yescrypt |

Worker name is `screen.rig`. The text before the dot is the party. `asic` or `gpu` in the password marks the device.

## Check it

```
./aol-server --selftest
```

Signup, a lobby line, and mail. Then:

```
curl -s http://127.0.0.1:8080/api/health
curl -s http://127.0.0.1:8080/api/pool
```

Health returns users, sessions, messages, accepted shares, workers. The report window on Windows shows the chain line and one line per module.

## Show a friend

On the host machine, tunnel 8080 (and 3333 if they will mine):

```
cloudflared tunnel --url http://127.0.0.1:8080
```

Or `ngrok http 8080`. Give them the URL. They sign up in a browser. A miner points `--host` at that name and `--port` at the pool port you also exposed.

## Coin fetch

http://127.0.0.1:8080/admin with `AOL_ADMIN` set. Repo must be `https://github.com/` or `https://gitlab.com/`. The host clones into `coin-src/` and writes `coin.cfg`. It does not compile the validator.
