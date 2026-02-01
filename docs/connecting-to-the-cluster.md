# Connecting to the Cluster

## Bastion Session Expiration
Bastion sessions are time-limited. The exact TTL depends on the bastion’s max session TTL setting. When a session expires, you must create a new session.

## Access from a Different Machine
To access from another machine:
1. Ensure the new machine’s public IP is in `bastion_allowed_cidrs`.
2. Create a new bastion session using that machine’s SSH public key.
3. Run the SSH tunnel command on that machine.
4. Point kubeconfig to `https://127.0.0.1:6443` and run `kubectl`.

## Create a Bastion Session (CLI)
```
oci bastion session create-port-forwarding \
  --bastion-id <bastion_ocid> \
  --ssh-public-key-file <path_to_public_key> \
  --target-private-ip <private_api_ip> \
  --target-port 6443
```

## Get SSH Tunnel Command
```
oci bastion session get --session-id <session_ocid> | jq -r '.data."ssh-metadata".command'
```

Run the command to open the tunnel, then:
```
kubectl get nodes
```
