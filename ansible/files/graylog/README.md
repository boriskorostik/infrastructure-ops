# Graylog log collection

## Inputs to create in Graylog

Create these inputs on the Graylog node:

- `Syslog TCP` on port `1514`, bind `0.0.0.0`
- `Syslog UDP` on port `1514`, bind `0.0.0.0`
- `GELF UDP` on port `12201`, bind `0.0.0.0`
- optional `GELF TCP` on port `12201`, bind `0.0.0.0`

Use Syslog TCP for Linux servers and ARM hosts. Use Syslog UDP for MikroTik.

## Linux / ARM forwarding

Run:

```bash
cd /home/boris/mikrotik_ansible
ansible-playbook -i inventory_arm_clvr.ini playbooks/graylog_rsyslog.yml --limit arm_clvr
```

For another inventory:

```bash
ansible-playbook -i inventory.ini playbooks/graylog_rsyslog.yml
```

## MikroTik syslog

On RouterOS:

```routeros
/system logging action add name=graylog target=remote remote=172.16.0.5 remote-port=1514 src-address=0.0.0.0 bsd-syslog=yes syslog-facility=local7
/system logging add topics=system,info action=graylog
/system logging add topics=account,info action=graylog
/system logging add topics=firewall,warning action=graylog
/system logging add topics=critical action=graylog
```

For firewall detection, use log prefixes in firewall rules such as:

- `DROP_WAN`
- `PORTSCAN`
- `BRUTE_SSH`
- `BRUTE_WINBOX`
- `DNS_ABUSE`
- `SYN_FLOOD`

## Useful Graylog searches

```text
source:arm*
```

```text
"Failed password" OR "authentication failure" OR "Invalid user"
```

```text
DROP_WAN OR PORTSCAN OR BRUTE_SSH OR BRUTE_WINBOX OR SYN_FLOOD
```

```text
programname:sshd AND ("Failed password" OR "Accepted password" OR "Accepted publickey")
```
