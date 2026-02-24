# WireGuard Network Stack

A Docker Compose stack that runs WireGuard as both a Mullvad VPN client and a WireGuard server, with PiHole for ad-blocking DNS, Traefik as an HTTPS reverse proxy, and services that can selectively bypass the kill switch.

For a full walkthrough, see the accompanying blog post: [Running WireGuard as Client and Server in Docker with PiHole and Traefik](https://jmartins.dev/posts/wireguard-docker-vpn-server).

## Architecture

The WireGuard container sits at the centre of the stack, running two interfaces simultaneously:

- **`wg0`** — Server interface accepting connections from remote peers (laptop, phone, etc.)
- **`wg1`** — Client interface tunnelling outbound traffic through Mullvad VPN

PiHole and Traefik share the WireGuard container's network namespace via `network_mode: service:wireguard`. Remote clients connect through `wg0`, get ad-blocking DNS from PiHole, HTTPS routing from Traefik, and all outbound traffic exits through the Mullvad tunnel on `wg1`.

A kill switch blocks all outbound traffic if the VPN connection drops. Services that need to maintain connectivity regardless of VPN state (e.g. ntfy for push notifications) run on their own Docker network, bypassing the kill switch.

## Services

| Service | Role | Network |
|---------|------|---------|
| **WireGuard** | VPN client + server | Own namespace (both networks) |
| **PiHole** | Ad-blocking DNS, custom domain resolution | Shares WireGuard's namespace |
| **Traefik** | HTTPS reverse proxy with Let's Encrypt wildcard certs | Shares WireGuard's namespace |
| **Docker Socket Proxy** | Restricted Docker API access for Traefik | Internal network only |
| **Jellyfin** | Media server (example: behind kill switch) | Shares WireGuard's namespace |
| **ntfy** | Push notifications (example: outside kill switch) | Default network |

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/joaommartins/wireguard-network-stack.git
cd wireguard-network-stack
```

### 2. Configure Environment Variables

Copy and edit the `.env` file with your values:

```bash
cp .env .env.local  # optional: keep the original as reference
```

Key variables to set:

| Variable | Description |
|----------|-------------|
| `CONFIG_DIR` | Path to store all service configuration data |
| `MOVIE_BACKUPS_DIR` | Path to media files for Jellyfin |
| `DOMAIN` | Your domain (e.g. `example.com`) — used for Traefik routing and PiHole DNS |
| `WIREGUARD_PEERS` | Comma-separated list of peer names (e.g. `laptop,phone`) |
| `WIREGUARD_SERVERURL` | Public hostname or IP for WireGuard server |
| `PIHOLE_PASSWORD` | PiHole admin interface password |
| `ACME_EMAIL` | Email for Let's Encrypt certificate registration |
| `CF_DNS_API_TOKEN` | Cloudflare API token for DNS-01 challenge |

### 3. Add Your Mullvad Configuration

Place your Mullvad WireGuard client configuration at `${CONFIG_DIR}/wireguard/wg1.conf`:

```ini
[Interface]
PrivateKey = <your-mullvad-private-key>
Address = <your-mullvad-address>/32
DNS = 127.0.0.1

[Peer]
PublicKey = <mullvad-server-public-key>
AllowedIPs = 0.0.0.0/0
Endpoint = <mullvad-server-endpoint>:51820
```

Note: `DNS` is set to `127.0.0.1` so the container's own DNS queries go through PiHole.

### 4. Start the Stack

```bash
docker compose up -d
```

On first run, the Linuxserver.io WireGuard image generates the server configuration (`wg0.conf`) and peer configurations in `${CONFIG_DIR}/wireguard/peer_*/`.

### 5. Configure the Server Interface

After the first run, edit `${CONFIG_DIR}/wireguard/wg_confs/wg0.conf` to add forwarding and NAT rules:

```ini
[Interface]
Address = 10.0.2.1
ListenPort = 51820
PrivateKey = <generated-private-key>
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o wg1 -j MASQUERADE
FwMark = 51820

[Peer] # peer_laptop
PublicKey = <generated-public-key>
AllowedIPs = 10.0.2.2/32
```

The `PostUp` rules enable packet forwarding and NAT so peer traffic exits through the Mullvad tunnel. `FwMark = 51820` exempts the server's own encrypted packets from the kill switch.

Then restart the stack:

```bash
docker compose restart wireguard
```

### 6. Connect Your Devices

Import the generated peer configuration from `${CONFIG_DIR}/wireguard/peer_<name>/peer_<name>.conf` on your device, or scan the QR code PNG with the WireGuard mobile app.

## Kill Switch

The startup script (`configs/wireguard_startup/iptables.sh`) installs iptables rules that:

1. Allow traffic to RFC 1918 private address ranges via the default gateway
2. Block all outbound traffic not going through `wg1`, not marked with `0xca6c` (port 51820 in hex), and not destined for a local address
3. Bring up the Mullvad client interface (`wg1`)

If the VPN connection drops, all outbound traffic for services sharing WireGuard's network is blocked. Services on their own Docker network (like ntfy) are unaffected.

## Adding Services

### Behind the kill switch

Use `network_mode: service:wireguard` and add Traefik labels to the **wireguard** container:

```yaml
  my-service:
    image: my-image
    network_mode: service:wireguard
    depends_on:
      pihole:
        condition: service_healthy
    restart: always
```

Then add labels on the wireguard service and expose the port:

```yaml
  # On the wireguard service:
  ports:
    - <port>:<port>
  labels:
    - traefik.http.routers.my-service.entrypoints=websecure
    - traefik.http.routers.my-service.rule=Host(`my-service.${DOMAIN}`)
    - traefik.http.routers.my-service.service=my-service
    - traefik.http.services.my-service.loadbalancer.server.port=<port>
```

### Outside the kill switch

Give the service its own network and define labels on its own container:

```yaml
  my-service:
    image: my-image
    labels:
      - traefik.enable=true
      - traefik.http.routers.my-service.entrypoints=websecure
      - traefik.http.routers.my-service.rule=Host(`my-service.${DOMAIN}`)
      - traefik.http.routers.my-service.tls.certresolver=letsencrypt
      - traefik.http.routers.my-service.service=my-service
      - traefik.http.services.my-service.loadbalancer.server.port=<port>
    restart: always
```

## Verification

From a connected device:

```bash
# Confirm traffic exits through Mullvad
curl https://am.i.mullvad.net/connected

# Verify PiHole resolves your domain to the tunnel address
dig +short jellyfin.example.com @10.0.2.1

# Test HTTPS routing through Traefik
curl -sI https://jellyfin.example.com
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
