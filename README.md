# Local Peppol Sandbox

A complete local Peppol network for testing document exchange without connecting to any external infrastructure.

## Components

| Component | Port | Image | Description |
|-----------|------|-------|-------------|
| **SMP** | 8080 | phelger/phoss-smp-xml | Service Metadata Publisher - the addressbook/registry |
| **AP1** | 8081 | norstella/oxalis-as4 | Access Point 1 - sends/receives documents |
| **AP2** | 8082 | norstella/oxalis-as4 | Access Point 2 - sends/receives documents |

## Architecture

```
┌─────────────┐         ┌─────────────┐
│   Sender    │         │  Receiver   │
│  (Company)  │         │  (Company)  │
└──────┬──────┘         └──────▲──────┘
       │                       │
       ▼                       │
┌─────────────┐         ┌─────────────┐
│    AP1      │────────►│    AP2      │
│  (Oxalis)   │  AS4    │  (Oxalis)   │
│  :8081      │         │  :8082      │
└──────┬──────┘         └─────────────┘
       │
       │ Lookup
       ▼
┌─────────────┐
│    SMP      │
│ (phoss-smp) │
│  :8080      │
└─────────────┘
```

## Quick Start

### 1. Generate Certificates (if not already present)

```bash
chmod +x scripts/*.sh
./scripts/generate-certs.sh
```

This creates:
- Root CA certificate
- SMP signing certificate
- AP1 and AP2 certificates
- Shared truststore

### 2. Start the Network

```bash
docker-compose up -d
```

Wait for all services to be healthy:
```bash
docker-compose ps
docker-compose logs -f  # Watch startup logs
```

### 3. Access the SMP

Open http://localhost:8080 in your browser.

**Login credentials:**
- Username: `admin@helger.com`
- Password: `password`

⚠️ **Change the password immediately in production!**

### 4. Register Test Participants

```bash
./scripts/register-participants.sh
```

This registers:
- `9915:test-sender-001` → AP1 (http://ap1:8080/as4)
- `9915:test-receiver-001` → AP2 (http://ap2:8080/as4)

### 5. Test Connectivity

```bash
./scripts/test-connectivity.sh
```

### 6. Check AP Endpoints

- AP1 AS4 endpoint: http://localhost:8081/as4
- AP2 AS4 endpoint: http://localhost:8082/as4

## Directory Structure

```
peppol-sandbox/
├── docker-compose.yml      # Main compose file
├── certs/                  # Generated certificates
│   ├── ca-cert.pem         # Root CA
│   ├── smp-keystore.jks    # SMP keystore
│   ├── ap1-keystore.jks    # AP1 keystore
│   ├── ap2-keystore.jks    # AP2 keystore
│   └── truststore.jks      # Shared truststore
├── smp-config/
│   └── application.properties
├── ap1-config/
│   └── oxalis.conf         # HOCON format config
├── ap2-config/
│   └── oxalis.conf         # HOCON format config
├── test-data/
│   └── sample-invoice.xml  # Sample Peppol BIS 3 invoice
└── scripts/
    ├── generate-certs.sh
    ├── register-participants.sh
    └── test-connectivity.sh
```

## Configuration Details

### SMP Configuration

Key settings in `smp-config/application.properties`:

| Property | Value | Description |
|----------|-------|-------------|
| `sml.active` | `false` | No SML integration (local only) |
| `smp.directory.integration.enabled` | `false` | No Peppol Directory |
| `smp.rest.writable.api.disabled` | `false` | Enable REST API writes |

### Access Point Configuration

Key settings in `ap*-config/oxalis.conf` (HOCON format):

| Property | Value | Description |
|----------|-------|-------------|
| `oxalis.operation.mode` | `TEST` | Test mode (allows self-signed certs) |
| `oxalis.lookup.locator.class` | `StaticLocator` | Direct SMP lookup (no SML) |
| `oxalis.lookup.locator.hostname` | `http://smp:8080` | Local SMP address |
| `access.point.isReceiverCheckEnabled` | `false` | Skip receiver validation |

## Test Identifiers

This sandbox uses:
- **Identifier scheme:** `9915` (test identifier)
- **Document type:** UBL Invoice 2.1 (Peppol BIS Billing 3.0)
- **Process:** `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0`
- **Transport profile:** `peppol-transport-as4-v2_0`

## Sending Test Documents

To send actual AS4 messages, you'll need an AS4 client. Options:

### Option 1: Use Oxalis Standalone CLI (external)

Download Oxalis Standalone and run:
```bash
java -jar oxalis-standalone.jar \
    -f sample-invoice.xml \
    -r "9915:test-receiver-001" \
    -s "9915:test-sender-001" \
    -u http://localhost:8080/
```

### Option 2: Use phase4 (Java library)

See https://github.com/phax/phase4 for a Java-based AS4 sender.

### Option 3: Direct SOAP/ebMS3

Send properly formatted AS4 messages to `http://localhost:8081/as4`

## Common Tasks

### View SMP Logs
```bash
docker-compose logs -f smp
```

### View AP Logs
```bash
docker-compose logs -f ap1
docker-compose logs -f ap2
```

### Query SMP via API
```bash
# Get participant info
curl "http://localhost:8080/iso6523-actorid-upis%3A%3A9915%3Atest-receiver-001"
```

### Check Received Files
```bash
docker exec peppol-ap2 ls -la /var/peppol/inbound/
```

### Stop the Network
```bash
docker-compose down
```

### Reset Everything
```bash
docker-compose down -v
rm -rf certs/*
./scripts/generate-certs.sh
docker-compose up -d
```

## Troubleshooting

### SMP not starting
- Check logs: `docker-compose logs smp`
- Verify certificates exist in `certs/`
- Ensure `application.properties` is valid

### APs not starting
- Wait longer - they depend on SMP being healthy first
- Check logs: `docker-compose logs ap1`
- Verify oxalis.conf syntax (HOCON format)

### Certificate errors
- Regenerate all certs: `./scripts/generate-certs.sh`
- Restart containers: `docker-compose restart`

### SMP lookup fails
- Ensure participant is registered: check SMP UI at http://localhost:8080
- Verify AP config points to `http://smp:8080` (Docker network name)

## Extending the Sandbox

### Add More Participants
1. Generate new certificate in `generate-certs.sh`
2. Add new AP service in `docker-compose.yml`
3. Create config in `apN-config/oxalis.conf`
4. Register in SMP

### Different Document Types
Modify `register-participants.sh` to register additional document types.

### Connect to Real Test Network
1. Register with OpenPeppol for test certificates
2. Enable SML integration in SMP config
3. Replace self-signed certs with Peppol test certs

## Resources

- [phoss-SMP Wiki](https://github.com/phax/phoss-smp/wiki)
- [Oxalis AS4 Documentation](https://github.com/OxalisCommunity/Oxalis-AS4)
- [Peppol Specifications](https://peppol.org/documentation/)

## License

Configuration files provided as-is for testing purposes.

Components used:
- [phoss-SMP](https://github.com/phax/phoss-smp) - Apache 2.0
- [Oxalis](https://github.com/OxalisCommunity/oxalis) - EUPL 1.2
