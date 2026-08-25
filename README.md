# Minecraft Server Docker Deployment

A containerized setup to run a self-hosted Minecraft Java Edition server using Docker and
Docker Compose.

---

## Table of Contents

- [Minecraft Server Docker Deployment](#minecraft-server-docker-deployment)
  - [Table of Contents](#table-of-contents)
  - [Quickstart](#quickstart)
  - [Testing](#testing)
  - [Usage and Configuration](#usage-and-configuration)
    - [Environment Variables](#environment-variables)
    - [Changing the Server Port](#changing-the-server-port)
    - [Adjusting Memory Allocation](#adjusting-memory-allocation)
    - [Configuring Server Properties](#configuring-server-properties)
    - [Changing the Minecraft Version](#changing-the-minecraft-version)
    - [Data Persistence](#data-persistence)
  - [Overview](#overview)
    - [Repository Contents](#repository-contents)
    - [How It Works](#how-it-works)

---

## Quickstart

**Prerequisites:** `docker` and `docker compose` installed on the host.

**Step 1 — Clone the repository**

```bash
git clone git@github.com:WaldemarChorow/mc-server-project.git
cd mc-server-project
```

**Step 2 — Download the Minecraft server binary**

The server JAR is not part of this repository. Download the Java Edition server from
[minecraft.net](https://www.minecraft.net/en-us/download/server) and save it as `server.jar` in
the project root:

```bash
curl -o server.jar <DOWNLOAD_URL_FROM_MINECRAFT_NET>
```

**Step 3 — Create the environment file**

```bash
cp .env.example .env
```

The defaults work as-is. Check that `MC_MEMORY_MAX` fits the host's available RAM (`free -h`).

**Step 4 — Start the server**

```bash
docker compose up -d --build
```

**Step 5 — Wait for startup**

```bash
docker compose logs -f mc-server
```

The first start generates the world and takes a minute or two. Wait for:

```
Done (XX.XXXs)! For help, type "help"
```

Press `Ctrl+C` to stop following the logs — the server keeps running.

The server is now reachable at `YOUR_SERVER_IP:8888`.

---

## Testing

There are two ways to confirm the server is reachable.

**Option A — Using the mcstatus Python module**

[mcstatus](https://github.com/py-mine/mcstatus) queries a Minecraft server without starting the
game.

```bash
pip install mcstatus
mcstatus YOUR_SERVER_IP:8888 status
```

Expected output:

```
version: Java 26.2 (protocol 776)
motd: A Minecraft Server
players: 0/20
ping: 28.17 ms
```

To measure only the latency:

```bash
mcstatus YOUR_SERVER_IP:8888 ping
```

**Option B — Using the Minecraft client**

1. Start Minecraft Java Edition.
2. Select **Multiplayer** → **Add Server**.
3. Enter `YOUR_SERVER_IP:8888` as the server address.
4. Save and join.

**Testing data persistence**

Restart the container and confirm the world is still there:

```bash
docker compose down
docker compose up -d
```

Query the server again with `mcstatus`, or rejoin from the client. Anything built before the
restart is still in place.

> Use `docker compose down`, never `docker compose down -v` — the `-v` flag deletes the volume
> and with it the entire world.

---

## Usage and Configuration

### Environment Variables

Configuration lives in `.env` and is read by `docker-compose.yaml` using `${VARIABLE:-default}`
syntax. Every variable has a default, so the server starts even without a `.env` file.

| Variable | Description | Default |
| --- | --- | --- |
| `MC_PORT` | Host port published to the internet | `8888` |
| `MC_MEMORY_MIN` | Initial Java heap size (`-Xms`) | `1G` |
| `MC_MEMORY_MAX` | Maximum Java heap size (`-Xmx`) | `2G` |
| `MC_MOTD` | Message shown in the server list | `A Minecraft Server` |
| `MC_DIFFICULTY` | `peaceful`, `easy`, `normal`, `hard` | `easy` |
| `MC_GAMEMODE` | `survival`, `creative`, `adventure`, `spectator` | `survival` |
| `MC_MAX_PLAYERS` | Player slots | `20` |
| `MC_ONLINE_MODE` | Verify players against Mojang accounts | `true` |
| `MC_PVP` | Allow player-versus-player combat | `true` |
| `MC_VIEW_DISTANCE` | Render distance in chunks | `10` |
| `MC_LEVEL_NAME` | World directory name | `world` |

`.env` is not committed to version control. Copy `.env.example` and adjust it for the target host.

### Changing the Server Port

The container always listens on 25565 internally. The published host port is configurable — edit
`.env`:

```env
MC_PORT=25565
```

Apply the change:

```bash
docker compose up -d
```

The new port must also be open in the host's firewall.

### Adjusting Memory Allocation

For more players or a larger world, raise the heap limit in `.env`:

```env
MC_MEMORY_MIN=2G
MC_MEMORY_MAX=4G
```

Apply with `docker compose up -d`.

Leave headroom for the operating system — do not assign the host's full RAM. The JVM needs
roughly 25% beyond the heap for its own bookkeeping. On a 4 GB host, `2G` is a sensible maximum.
Check available memory with `free -h`.

### Configuring Server Properties

Game settings such as difficulty, MOTD, and player limit are set through environment variables in
`.env`. On first start, the entrypoint script generates `/data/server.properties` from them:

```env
MC_MOTD=Welcome to my server
MC_DIFFICULTY=hard
MC_MAX_PLAYERS=10
```

Apply with `docker compose up -d`.

These values are applied **only when `server.properties` does not yet exist**, so settings
changed in-game are never overwritten on restart. To regenerate the file from the environment,
delete it first:

```bash
docker compose exec mc-server rm /data/server.properties
docker compose restart mc-server
```

Settings not covered by an environment variable can be edited directly in
`/data/server.properties`.

### Changing the Minecraft Version

The version is determined by `server.jar` in the project root:

1. Download the new server JAR from
   [minecraft.net](https://www.minecraft.net/en-us/download/server) and replace the existing file.
2. If the new version requires a newer Java release, update the `FROM` line in the `Dockerfile`.
3. Rebuild:

   ```bash
   docker compose up -d --build
   ```

The world is preserved. Back it up first — Minecraft migrates world data on upgrade, and this
cannot be undone.

### Data Persistence

World data, player data, and `server.properties` are stored in the named volume `mc_data`,
mounted at `/data` inside the container. Restarting the container, rebooting the host, or
rebuilding the image leaves the world intact.

To back up the world:

```bash
docker compose down
docker run --rm -v mc-server-project_mc_data:/data -v "$(pwd)":/backup \
  alpine tar czf /backup/mc-backup.tar.gz -C /data .
docker compose up -d
```

The service is configured with `restart: unless-stopped`, so the container restarts
automatically after a crash or a host reboot.

---

## Overview

This repository builds and runs a Minecraft Java Edition server in a Docker container. The image
is assembled from a plain Java runtime plus the official Minecraft server binary — no pre-built
Minecraft image is used.

### Repository Contents

| File | Purpose |
| --- | --- |
| `Dockerfile` | Builds the image on Java 25 (Eclipse Temurin JRE) and copies in the server binary and entrypoint script. |
| `docker-compose.yaml` | Defines the `mc-server` service: build, port mapping, environment, volume, restart policy. |
| `docker-entrypoint.sh` | Runs at container start: accepts the EULA, generates `server.properties` from environment variables, then launches the server. |
| `.env.example` | Template for `.env`, documenting all configurable values. |
| `.gitignore` | Excludes `.env`, the server binary, and Minecraft runtime files. |
| `README.md` | This document. |

`server.jar` is downloaded during setup (Quickstart step 2) and is deliberately not committed:
the Minecraft server binary is not redistributable, and a ~50 MB binary does not belong in Git.

### How It Works

Java 25 is required because Minecraft 26.2 does not run on older runtimes — they reject the JAR
with `UnsupportedClassVersionError`.

Inside the container, code and data are kept in separate directories:

| Path | Contents | Persisted |
| --- | --- | --- |
| `/app` | `server.jar`, `docker-entrypoint.sh` | No — part of the image |
| `/data` | World, `server.properties`, logs, `eula.txt` | Yes — via the `mc_data` volume |

The server process runs with `/data` as its working directory, so everything it writes lands in
the volume and survives rebuilds.

Startup is handled by `docker-entrypoint.sh` rather than a direct `java` call. This keeps
configuration flexible: the EULA is accepted, `server.properties` is generated from environment
variables on first start, and the JVM is then launched via `exec` so it becomes PID 1 and
receives Docker's stop signals directly for a clean shutdown.
