#!/usr/bin/env python3
"""Relay MCP OAuth callbacks from the host browser into claude-docker containers.

When Claude Code authenticates an HTTP MCP server it waits for the browser to
hit http://localhost:<port>/callback. Inside a container that listener is on the
container's loopback, so the host browser's redirect lands nowhere.

This relay listens on 127.0.0.1:<port> on the host for every MCP server with a
pinned `oauth.callbackPort` in ~/.claude.json, and replays each /callback
request inside the running containers with `docker exec ... curl`. The first
container with a listener on that port gets it. No container ports are
published.

Started by the claude-docker launchers. Binds synchronously (so port problems
are reported in the launching terminal), then detaches and exits once no
claude-docker containers are left.
"""

import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

IMAGE = "claude-dev-ubuntu:latest"
CALLBACK_PATH = "/callback"
# Lets a second launcher recognise a port already held by a relay.
IDENTITY_PATH = "/claude-docker-oauth-relay"
LOG_PATH = os.path.join(tempfile.gettempdir(), "claude-docker-oauth-relay.log")
CURL_CONNECTION_REFUSED = 7
IDLE_CHECK_SECONDS = 60


def pinned_callback_ports():
    """Every oauth.callbackPort in ~/.claude.json (user and local scope)."""
    try:
        with open(os.path.expanduser("~/.claude.json")) as config_file:
            config = json.load(config_file)
    except (OSError, ValueError):
        return []

    server_groups = [config.get("mcpServers") or {}]
    for project in (config.get("projects") or {}).values():
        server_groups.append(project.get("mcpServers") or {})

    ports = set()
    for servers in server_groups:
        for server in servers.values():
            callback_port = (server.get("oauth") or {}).get("callbackPort")
            if isinstance(callback_port, int):
                ports.add(callback_port)
    return sorted(ports)


def running_containers():
    result = subprocess.run(
        ["docker", "ps", "-q", "--filter", "ancestor=" + IMAGE],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.split()


def deliver_callback(port, path_and_query):
    """Replay the callback inside each container until one has a listener.

    Returns (status, content_type, body, redirect_url), or None if no container
    was waiting.
    """
    container_url = "http://localhost:%d%s" % (port, path_and_query)
    for container_id in running_containers() or []:
        result = subprocess.run(
            [
                "docker", "exec", container_id,
                "curl", "-s", "--max-time", "30", "-o", "-",
                "-w", "\n%{http_code}\t%{content_type}\t%{redirect_url}",
                container_url,
            ],
            capture_output=True,
        )
        if result.returncode == CURL_CONNECTION_REFUSED:
            continue
        if result.returncode != 0:
            log("container %s: curl exited %d" % (container_id, result.returncode))
            continue
        body, _, status_line = result.stdout.rpartition(b"\n")
        status_code, content_type, redirect_url = status_line.decode().split("\t")
        log("delivered callback on port %d to container %s" % (port, container_id))
        return int(status_code), content_type or "text/html", body, redirect_url
    return None


class CallbackRelayHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        port = self.server.server_address[1]
        path = self.path.split("?", 1)[0]

        if path == IDENTITY_PATH:
            self.respond(200, "text/plain", b"claude-docker-oauth-relay")
        elif path == CALLBACK_PATH:
            delivered = deliver_callback(port, self.path)
            if delivered is None:
                self.respond(
                    502,
                    "text/plain",
                    b"No claude-docker container is waiting for this callback.\n"
                    b"Start the sign-in from /mcp in Claude, then try again.",
                )
            else:
                self.respond(*delivered)
        else:
            self.respond(404, "text/plain", b"Not found")

    def respond(self, status, content_type, body, redirect_url=""):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        if redirect_url:
            self.send_header("Location", redirect_url)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        log("%s %s" % (self.address_string(), format % args))


def log(message):
    sys.stderr.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), message))
    sys.stderr.flush()


def port_held_by_relay(port):
    try:
        url = "http://127.0.0.1:%d%s" % (port, IDENTITY_PATH)
        with urllib.request.urlopen(url, timeout=1) as response:
            return response.read() == b"claude-docker-oauth-relay"
    except Exception:
        return False


def bind_servers(ports):
    servers = []
    for port in ports:
        try:
            servers.append(ThreadingHTTPServer(("127.0.0.1", port), CallbackRelayHandler))
        except OSError:
            if not port_held_by_relay(port):
                print(
                    "Warning: MCP OAuth callback port %d is in use by another program; "
                    "sign-in for MCP servers using it won't reach the container." % port,
                    file=sys.stderr,
                )
    return servers


def detach():
    """Fork into the background and send output to the log file."""
    if os.fork() > 0:
        os._exit(0)
    os.setsid()
    log_file = open(LOG_PATH, "a")
    devnull = open(os.devnull)
    os.dup2(devnull.fileno(), sys.stdin.fileno())
    os.dup2(log_file.fileno(), sys.stdout.fileno())
    os.dup2(log_file.fileno(), sys.stderr.fileno())


def main():
    servers = bind_servers(pinned_callback_ports())
    if not servers:
        return

    detach()
    log("relaying ports %s" % ", ".join(str(s.server_address[1]) for s in servers))
    for server in servers:
        threading.Thread(target=server.serve_forever, daemon=True).start()

    # The launcher starts us just before its container, so check after a delay.
    while True:
        time.sleep(IDLE_CHECK_SECONDS)
        if running_containers() == []:
            log("no claude-docker containers running; exiting")
            return


if __name__ == "__main__":
    main()
