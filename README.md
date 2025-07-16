# WireGuard Network Stack

This repository is an example setup for running a WireGuard VPN server and a client container sharing its network stack using Docker Compose. It includes a `speedtest-tracker` container that operates within the WireGuard network.

## Features

- **WireGuard VPN**: A secure VPN server configured with Docker.
- **Shared Network Stack**: The `speedtest-tracker` container shares the WireGuard container's network stack.
- **Health Checks**: Both containers include health checks to ensure proper operation.
- **Customizable Configuration**: Environment variables and configuration files allow for easy customization.

## Repository Structure

- `docker-compose.yaml`: Defines the services and their configurations.
- `.env`: Contains environment variables for customization.
- `configs/wireguard/wg_confs/wg0.conf`: WireGuard client configuration file.

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/wireguard-network-stack.git
cd wireguard-network-stack
```

### 2. Configure Environment Variables

Edit the `.env` file to set your desired values for `PUID`, `PGID`, `TZ`, and `CONFIG_DIR`.

### 3. Generate Sensitive Data

#### Regenerate the Private Key

The private key in `wg0.conf` is redacted for security. You must generate a new private key:

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

- Replace the `[redacted]` value in `wg0.conf` with the contents of the `privatekey` file.
- Use the `publickey` file to configure peers.

#### Generate a New `APP_KEY`

The `APP_KEY` in `.env` is used by the `speedtest-tracker` container. Regenerate it using:

```bash
echo -n 'base64:'; openssl rand -base64 32
```

Replace the existing `APP_KEY` value in `.env` with the new one.

### 4. Start the Services

Run the following command to start the containers:

```bash
docker-compose up -d
```

### 5. Verify Health Checks

Ensure both services are running and healthy:

```bash
docker compose ps
```

### 6. Access the Services

- **Speedtest Tracker**: Access the web interface at `http://localhost:8080`.

## Notes

- The `speedtest-tracker` container uses the `network_mode: service:wireguard` setting to share the WireGuard container's network stack.
- The `wg0.conf` file must be updated with the correct private key and peer information before use.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
