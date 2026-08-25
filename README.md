# Minecraft Server Docker Deployment

This repository provides a containerized setup to launch, configure, and manage a self-hosted Minecraft Java Edition server using Docker and Docker Compose.

---

## Table of Contents

- [Minecraft Server Docker Deployment](#minecraft-server-docker-deployment)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [Repository Contents](#repository-contents)
    - [Container Layout](#container-layout)
  - [Quickstart](#quickstart)
  - [Usage and Configuration](#usage-and-configuration)
    - [Environment Variables](#environment-variables)
    - [Changing the Server Port](#changing-the-server-port)
    - [Adjusting Memory Allocation](#adjusting-memory-allocation)
    - [Changing the Minecraft Version](#changing-the-minecraft-version)
    - [Server Properties](#server-properties)
    - [Data Persistence](#data-persistence)
    - [Restart Behaviour](#restart-behaviour)
  - [Troubleshooting](#troubleshooting)

---

## Overview

The purpose of this repository is to automate the deployment of a Minecraft Java Edition server
inside a Docker container. The image is assembled from a plain Java runtime and the official
Minecraft server binary — no pre-built Minecraft image is used, so every layer of the setup is
explicit and auditable.

### Repository Contents

| File | Purpose |
| --- | --- |
| `Dockerfile` | Builds the container image on top of Java 25 (Eclipse Temurin JRE) and defines how the server process is started. |
| `docker-compose.yaml` | Defines the `mc-server` service: image build, port mapping, environment, volume, and restart policy. |
| `server.jar` | The official Minecraft Java Edition server binary, downloaded from [minecraft.net](https://www.minecraft.net/en-us/download/server). Copied into the image at build time. |
| `.env` | Local, non-sensitive configuration (port, memory limits). Not committed to version control. |
| `.env.example` | Template for `.env`, documenting the expected keys and their defaults. |
| `.gitignore` | Excludes `.env` and Minecraft runtime files from version control. |
| `README.md` | This document. |

The image is based on Java 25 because Minecraft 26.2 requires it. Older runtimes refuse to load
the JAR and fail with `UnsupportedClassVersionError`.

### Container Layout

Application code and mutable data are deliberately kept in separate directories:

| Path | Contents | Persisted |
| --- | --- | --- |
| `/app` | `server.jar`, provided by the image | No |
| `/data` | World, `server.properties`, logs, `eula.txt` | Yes, via the `mc_data` volume |

The server process runs with `/data` as its working directory, so everything it writes lands in
the volume. Keeping the JAR outside `/data` matters: mounting a volume over the JAR's directory
would hide it and the container would fail to start.

---

## Quickstart

1. **Prerequisites**

   `docker` and `docker compose` installed on the host, and the target port reachable from the
   internet.

2. **Clone the repository**

   ```bash
   git clone https://github.com/Example/mc-server-project.git
   cd mc-server-project
   ```

3. **Create the environment file**

   ```bash
   cp .env.example .env
   ```

   The defaults work as-is. Check that `MC_MEMORY_MAX` fits the host's available RAM (`free -h`).

4. **Start the container**

   ```bash
   docker compose up -d --build
   ```

   The first start generates the world and takes a minute or two. Follow the progress with:

   ```bash
   docker compose logs -f mc-server
   ```

   Wait for `Done (XX.XXXs)! For help, type "help"`.

5. **Verify availability**

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

   Alternatively, connect from the Minecraft Java Edition client using
   `YOUR_SERVER_IP:8888` as the server address.

---

## Usage and Configuration

### Environment Variables

Configuration is supplied through the `.env` file and consumed by `docker-compose.yaml` using
`${VARIABLE:-default}` syntax. Every variable has a default, so the stack starts even when no
`.env` file is present.

| Variable | Description | Default |
| --- | --- | --- |
| `MC_PORT` | Host port published to the internet | `8888` |
| `MC_MEMORY_MIN` | Initial Java heap size (`-Xms`) | `2G` |
| `MC_MEMORY_MAX` | Maximum Java heap size (`-Xmx`) | `4G` |

Inside the container these arrive as `JAVA_MIN_MEM` and `JAVA_MAX_MEM`, which the startup
command reads. The `Dockerfile` sets fallback values for both, so the image also runs correctly
when started directly with `docker run`, without Compose.

`.env` is excluded from version control. `.env.example` is committed as a template — copy it and
adjust the values for the target host.

### Changing the Server Port

The container always listens on 25565 internally, the Minecraft default. The published host port
is configurable. To use a different one, edit `.env`:

```env
MC_PORT=25565
```

Apply the change:

```bash
docker compose up -d
```

The port must also be open in any firewall in front of the host — both the cloud provider's
firewall and a local one such as `ufw`.

### Adjusting Memory Allocation

To support more players or a larger world, raise the heap limit in `.env`:

```env
MC_MEMORY_MIN=4G
MC_MEMORY_MAX=8G
```

Then restart with `docker compose up -d`.

Do not assign the host's entire RAM. The JVM needs memory beyond the heap, and the operating
system needs headroom of its own — otherwise the kernel's OOM killer terminates the server
mid-game. On a 4 GB host, `2G` is a sensible maximum.

### Changing the Minecraft Version

The server version is determined by `server.jar` in the repository root. To upgrade:

1. Download the new `server.jar` from
   [minecraft.net](https://www.minecraft.net/en-us/download/server) and replace the existing file.
2. Check the Java requirement of the new version. If it exceeds Java 25, update the `FROM` line
   in the `Dockerfile` accordingly.
3. Rebuild:

   ```bash
   docker compose up -d --build
   ```

The world in the `mc_data` volume is preserved across the upgrade. Back it up first — Minecraft
migrates world data on version upgrades, and the change cannot be reverted.

### Server Properties

`server.properties` is generated in `/data` on first start and persists in the volume. To change
game settings such as difficulty, MOTD, or the player limit:

```bash
docker compose exec mc-server sh -c "sed -i 's/^difficulty=.*/difficulty=hard/' /data/server.properties"
docker compose restart mc-server
```

For repeated edits it is more convenient to stop the container and edit the file through a
temporary shell:

```bash
docker compose down
docker run --rm -it -v mc-server-project_mc_data:/data alpine vi /data/server.properties
docker compose up -d
```

### Data Persistence

World data, player data, and configuration live in the named Docker volume `mc_data`, mounted at
`/data`. Restarting the container, rebooting the host, or rebuilding the image leaves the world
intact.

To verify persistence:

```bash
docker compose down
docker compose up -d
mcstatus YOUR_SERVER_IP:8888 status
```

To back up the world:

```bash
docker compose down
docker run --rm -v mc-server-project_mc_data:/data -v "$(pwd)":/backup \
  alpine tar czf /backup/mc-backup.tar.gz -C /data .
docker compose up -d
```

> **Warning:** `docker compose down -v` deletes the volume and with it the entire world. Use
> plain `docker compose down` unless you explicitly intend to start over.

### Restart Behaviour

The service is configured with `restart: unless-stopped`. The container restarts automatically
after a crash or a host reboot, and stays down only when stopped explicitly with
`docker compose stop` or `docker compose down`.

Note that this also restarts a container that fails immediately at startup, producing a restart
loop. `docker ps` showing `Restarting (1)` is the signal to check the logs — see below.

---

## Troubleshooting

**The container restarts in a loop** — `docker ps` shows `Restarting (1)`.

Check the logs first:

```bash
docker compose logs --tail 50 mc-server
```

| Log message | Cause | Fix |
| --- | --- | --- |
| `Error: Unable to access jarfile` | The volume is mounted over the JAR's directory | World data belongs in `/data`; the JAR stays in `/app` and is referenced by absolute path |
| `UnsupportedClassVersionError: ... class file version 69.0` | The JRE is older than the JAR requires | Class file version 69.0 means Java 25, 65.0 means Java 21. Update the `FROM` line in the `Dockerfile` |
| `You need to agree to the EULA` | `eula.txt` missing from `/data` | The file is created during the image build. If the volume already existed without it, create it manually |
| Killed without an error message | The host ran out of memory | Lower `MC_MEMORY_MAX` and check `free -h` |

**The server is unreachable from outside.**

The failure mode indicates where to look:

* `Connection refused` — the packet reaches the host, but nothing is listening on that port. The
  container is not running, or the port is not mapped. Check that `docker ps` shows a mapping
  such as `0.0.0.0:8888->25565/tcp` in the `PORTS` column.
* Timeout — a firewall is dropping packets. Check the cloud provider's firewall rules and any
  local `ufw` configuration.

To distinguish the two:

```bash
ping -c 3 YOUR_SERVER_IP
nc -z -v -w5 YOUR_SERVER_IP 8888
```
