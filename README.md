# Minecraft Server Docker Deployment

A containerized setup to run a self-hosted Minecraft Java Edition server using Docker and
Docker Compose.

---

## Table of Contents

- [Minecraft Server Docker Deployment](#minecraft-server-docker-deployment)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Quickstart](#quickstart)
  - [Testing](#testing)
  - [Usage and Configuration](#usage-and-configuration)
    - [Environment Variables](#environment-variables)
    - [Changing the Server Port](#changing-the-server-port)
    - [Adjusting Memory Allocation](#adjusting-memory-allocation)
    - [Changing the Minecraft Version](#changing-the-minecraft-version)
    - [Data Persistence](#data-persistence)

---

## Overview

This repository builds and runs a Minecraft Java Edition server in a Docker container. The image
is assembled from a plain Java runtime plus the official Minecraft server binary — no pre-built
Minecraft image is used.

**Repository contents:**

| File | Purpose |
| --- | --- |
| `Dockerfile` | Builds the image on Java 25 (Eclipse Temurin JRE) and defines how the server starts. |
| `docker-compose.yaml` | Defines the `mc-server` service: build, port mapping, environment, volume, restart policy. |
| `server.jar` | Official Minecraft server binary from [minecraft.net](https://www.minecraft.net/en-us/download). |
| `.env` | Local configuration (port, memory). Not committed. |
| `.env.example` | Template for `.env`. |
| `.gitignore` | Excludes `.env` and Minecraft runtime files. |
| `README.md` | This document. |

Java 25 is required because Minecraft 26.2 does not run on older runtimes.

Inside the container, `server.jar` lives in `/app` and all world data in `/data`, which is
persisted through the `mc_data` volume.

---

## Quickstart

**Prerequisites:** `docker` and `docker compose` installed on the host.

**Step 1 — Clone the repository**

```bash
git clone https://github.com/Example/mc-server-project.git
cd mc-server-project
```

**Step 2 — Create the environment file**

```bash
cp .env.example .env
```

The defaults work as-is.

**Step 3 — Start the server**

```bash
docker compose up -d --build
```

**Step 4 — Wait for startup**

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

[mcstatus](https://github.com/py-mine/mcstatus) queries a Minecraft server without starting the game.

Install it:

```bash
pip install mcstatus
```

Query the server:

```bash
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
| `MC_MEMORY_MIN` | Initial Java heap size (`-Xms`) | `2G` |
| `MC_MEMORY_MAX` | Maximum Java heap size (`-Xmx`) | `4G` |

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
MC_MEMORY_MIN=4G
MC_MEMORY_MAX=8G
```

Apply with `docker compose up -d`.

Leave headroom for the operating system — do not assign the host's full RAM. On a 4 GB host,
`2G` is a sensible maximum. Check available memory with `free -h`.

### Changing the Minecraft Version

The version is determined by `server.jar` in the repository root:

1. Download the new `server.jar` from
   [minecraft.net](https://www.minecraft.net/en-us/download) and replace the existing file.
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
