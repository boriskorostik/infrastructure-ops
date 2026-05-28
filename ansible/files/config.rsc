# ===== Интерфейсы и бриджи =====
/interface bridge
add name=bridge

/interface bridge port
add bridge=bridge interface=ether2
add bridge=bridge interface=ether3
add bridge=bridge interface=ether4
add bridge=bridge interface=ether5

/interface list
add name=WAN
add name=LAN

/interface list member
add list=WAN interface=ether1
add list=LAN interface=bridge

# ===== IP адреса =====
/ip address
add address=10.13.16.1/20 interface=bridge network=10.13.16.0

/ip dns static
add address=10.13.16.1 comment=defconf name=router.lan

# ===== DHCP =====
/ip pool
add name=dhcp_pool ranges=10.13.16.2-10.13.31.254

/ip dhcp-server
add name=dhcp1 interface=bridge address-pool=dhcp_pool disabled=no

/ip dhcp-server network
add address=10.13.16.0/20 gateway=10.13.16.10 dns-server=10.13.16.10 \
    comment="Send LAN clients through VLESS app/TUN gateway"

/ip dhcp-client
add interface=ether1 disabled=no

# ===== DNS =====
/ip dns
set servers=77.88.8.8,8.8.8.8 allow-remote-requests=yes

# ===== Firewall Address List =====
/ip firewall address-list
add address=84.204.178.210 list=admin

# ===== NAT =====
/ip firewall nat
add action=masquerade chain=srcnat out-interface-list=WAN comment="Masquerade LAN"
add action=netmap chain=dstnat comment=ssh dst-port=22100 in-interface=ether1 \
    protocol=tcp to-addresses=10.13.16.10 to-ports=22100
add action=netmap chain=dstnat comment=inbuilding dst-port=29107 \
    in-interface=ether1 protocol=tcp to-addresses=10.13.16.10 to-ports=29107
add action=netmap chain=dstnat comment=inbuilding dst-port=19090 \
    in-interface=ether1 protocol=udp to-addresses=10.13.16.10 to-ports=19090
add action=netmap chain=dstnat comment=video dst-port=5000-5400 \
    in-interface=ether1 protocol=udp to-addresses=10.13.16.10 to-ports=5000-5400
add action=netmap chain=dstnat comment=video dst-port=5000-5100 \
    in-interface=ether1 protocol=tcp to-addresses=10.13.16.10 to-ports=5000-5100
add action=dst-nat chain=dstnat comment=askue in-interface-list=WAN port=6000 \
    protocol=tcp to-addresses=10.13.16.134 to-ports=6000
add action=netmap chain=dstnat comment=askue dst-port=14200 \
    in-interface-list=WAN log=yes protocol=tcp to-addresses=10.13.16.134 \
    to-ports=14200
add action=netmap chain=dstnat comment=askue dst-port=3000 \
    in-interface-list=WAN log=yes protocol=tcp to-addresses=10.13.16.134 \
    to-ports=14200
add action=netmap chain=dstnat comment=zbx in-interface-list=WAN protocol=icmp \
    src-address-list=admin to-addresses=10.13.16.10

# ===== Фаервол: filter =====
/ip firewall filter
# INPUT
add chain=input connection-state=established,related action=accept comment="Allow established/related"
add chain=input in-interface=bridge action=accept comment="Allow LAN access"
add chain=input src-address-list=admin action=accept comment="Allow Admin IP"
add chain=input protocol=tcp dst-port=11787 connection-state=new action=accept comment="Allow Winbox from Admin"

# DNS drop from WAN
add chain=input in-interface-list=WAN protocol=udp dst-port=53 action=drop comment="Drop DNS UDP from WAN"
add chain=input in-interface-list=WAN protocol=tcp dst-port=53 action=drop comment="Drop DNS TCP from WAN"

# DROP всего остального во входящем
add chain=input action=drop comment="Drop everything else"

# FORWARD
add chain=forward connection-state=established,related action=accept comment="Allow established/related (forward)"
add chain=forward in-interface=bridge action=accept comment="Allow LAN forwarding"
add chain=forward connection-state=new in-interface-list=WAN src-address-list=!admin action=drop comment="Drop new connections from WAN not from Admin"
add chain=forward action=drop comment="Drop everything else (forward)"

# ===== Firewall: Raw =====
/ip firewall raw
add chain=prerouting src-address-list=FB-WB-BAN action=drop
add chain=prerouting dst-port=5060 protocol=tcp in-interface-list=WAN action=drop
add chain=prerouting dst-port=5060 protocol=udp in-interface-list=WAN action=drop
add chain=prerouting src-address-list="block psd" action=drop

# ===== Firewall: Mangle =====
/ip firewall mangle
add action=jump chain=output content="invalid user name or password" \
    dst-address-list=!admin jump-target=FB-WB protocol=tcp src-port=11787
add action=add-dst-to-address-list address-list=FB-WB-BAN address-list-timeout=10m chain=FB-WB dst-address-list=FB-WB-3
add action=add-dst-to-address-list address-list=FB-WB-3 address-list-timeout=1m chain=FB-WB dst-address-list=FB-WB-2
add action=add-dst-to-address-list address-list=FB-WB-2 address-list-timeout=1m chain=FB-WB dst-address-list=FB-WB-1
add action=add-dst-to-address-list address-list=FB-WB-1 address-list-timeout=1m chain=FB-WB

# ===== Firewall: Service Ports =====
/ip firewall service-port
set ftp disabled=yes
set tftp disabled=yes
set irc disabled=yes
set h323 disabled=yes
set sip disabled=yes
set pptp disabled=yes


# ===== Services =====
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=59222 disabled=no
set api disabled=yes
set winbox port=11787
set api-ssl disabled=yes

# ===== SSH Configuration =====
/user ssh-keys
add user=admin key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC4LRL9iK1ADjsWn5ANMVyJIw7bblodya3qXIL0Yf8kjRcp/sITzryEDS8Iuj7YAQyqRBSO7jqUXbd7fqlwrCvJdI1rEuOBN5Ne/XLQ8bAEl90hggMXJngE0gWIzG2y7MN0hnIIy2pPU74Gg3KZU79JXCZ6rj1jbBcS1Pr5wMLrCRD1KyynKEgRUNRv8nwr6TFwtKhjMgLtcyvMR4IPf0922dCQkr5tyCM3aNMuOVqyNjWmmeFQ1vokbZ25ppLEnxP8Jh2UtNGcFemIwAbKQG3Sd4ouhQ29l4d+7PkhTOZxVSdTxlWD0in7Bn05cRrnAkDJPEMamgC26FQv9BxpVqqFuNEmv7Y+f2IqszSdFzvBT4gbUChAF1zLRvAlhzFCgy/uh6ZYdonoOx+Mzk591xtA0WIQZmTtOt1zhHH05bjLSQ6ROXcFrJ/cr7SSxkV5+M7WzcfLg+chozFnRp0+M1gHhoBmOD8vHBCcc9wJVxuqjkgGxSjbmxwZinG/r4G28ac= serw@bereg"

/ip ssh
set strong-crypto=yes
set always-allow-password-login=no

# ===== User Configuration =====
/user set [find name=admin] group=full password="CHANGE_ME"

# ===== System & Identity =====
/system identity
set name=MikroTikNEW

/system clock
set time-zone-name=Europe/Moscow

# ===== MAC Winbox доступ =====
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
