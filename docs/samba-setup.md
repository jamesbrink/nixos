# Samba Configuration on hal9000

## Overview

Samba has been configured on hal9000 to share the same storage paths that are currently exported via NFS. This provides SMB/CIFS access for Windows and macOS clients that may not have good NFS support.

## Shared Paths

| Share Name   | Path          | Description            |
| ------------ | ------------- | ---------------------- |
| storage-fast | /storage-fast | Fast ZFS storage array |

## Network Access

The Samba server is configured to allow connections from:

- Local network: `10.70.100.0/24`
- Tailscale network: `100.64.0.0/10`

## Security Configuration

- SMB2 is the minimum protocol version (more secure than SMB1)
- User authentication is required (no anonymous access)
- Server-side encryption is enabled
- WSDD is enabled for Windows 10/11 network discovery

## Firewall Ports

The following ports are automatically opened by the configuration:

- TCP 445 - SMB over TCP
- TCP 139 - NetBIOS Session Service
- UDP 137 - NetBIOS Name Service
- UDP 138 - NetBIOS Datagram Service
- TCP 5357 - WSDD (Windows Service Discovery)
- UDP 3702 - WSDD Discovery

## Setting Up Users

Before users can access Samba shares, they must:

1. Have a system account on hal9000
2. Have their Samba password set

To add or update a Samba user password:

```bash
# On hal9000 or in the development shell
samba-add-user [username]

# If no username is provided, it defaults to the current user
samba-add-user
```

## Connecting to Shares

### Windows

1. Open File Explorer
2. In the address bar, type: `\\hal9000\storage-fast`
3. Enter your username and Samba password when prompted

### macOS

1. In Finder, press Cmd+K
2. Enter: `smb://hal9000/storage-fast`
3. Enter your username and Samba password when prompted

### Linux

1. Using file manager: `smb://hal9000/storage-fast`
2. Using command line: `smbclient //hal9000/storage-fast -U username`

## Deployment

To deploy this configuration:

```bash
# Deploy to hal9000
deploy hal9000

# After deployment, set up user passwords
ssh hal9000
sudo smbpasswd -a jamesbrink
```

## Troubleshooting

### Check Samba status

```bash
sudo systemctl status smb
sudo systemctl status nmb
sudo systemctl status wsdd
```

### View Samba logs

```bash
sudo journalctl -u smb -f
sudo tail -f /var/log/samba/log.*
```

### Test connectivity

```bash
# List shares
smbclient -L hal9000 -U username

# Test authentication
smbclient //hal9000/storage-fast -U username -c 'ls'
```

### Windows discovery issues

If hal9000 doesn't appear in Windows Network:

1. Ensure WSDD service is running: `sudo systemctl status wsdd`
2. Check Windows has network discovery enabled
3. Try accessing directly via `\\hal9000` in Explorer

## Performance Tuning

The configuration includes several performance optimizations:

- TCP_NODELAY for reduced latency
- Large socket buffers (512KB)
- Async I/O enabled
- Write caching enabled (2MB)
- Sendfile support for zero-copy transfers

## Future Enhancements

Potential improvements that could be added:

1. Time Machine support for macOS backups
2. Additional shares for specific use cases
3. Shadow copies for file versioning
4. Integration with Active Directory (if needed)
5. Clustered Samba for high availability
