# geoip-powerdns-info
Return GeoIP data with an RBL-like interface using PowerDNS Recursor

This simple project uses [PowerDNS Recursor](https://doc.powerdns.com/recursor/) to return GeoIP information of any given IP (IPv4) address.

The idea is taken from the [rspamd](https://rspamd.com/) asn module. This modules queries &lt;reverse-ip&gt;.asn.rspamd.com and returns a TXT record that includes the autonomous system, network, country and region of the supplied IP address.

`geoip-info.lua` is a small LUA library that can be used as a `lua-dns-script` to capture DNS queries and return GeoIP data.

## Installation

This library returns NXDOMAIN for any queries that are not subdomains of the configured RBL domain. You should consider to use a dedicated PowerDNS Recursor instance for this RBL service. 

Even if you could change the code to allow both general and RBL queries, I prefer to isolate both instances and to use [dnsdist](https://dnsdist.org/) to route queries.

If we had the general PowerDNS Recursor instance running on localhost, port 53, and the RBL instance on localhost, port 5353, with `rbl.example.com` as our RBL domain, dnsdist should include:

```lua
setLocal('public_ip')

newServer({address="127.0.0.1", name="recursor1", pool="recursors"})
newServer({address="127.0.0.1:5353", name="rbl1", pool="rbls"})

-- rbl queries go to the rbl pool
addAction(makeRule({"rbl.example.com."}), PoolAction("rbls"))
-- everything else goes to the general service
addAction(AllRule(), PoolAction("recursors"))
```

### PowerDNS Recursor

I would recommend to download recent PowerDNS software from the [official repo](https://repo.powerdns.com/).

If you choose to run virtual instances, follow the [powerdns-auth guide](https://doc.powerdns.com/authoritative/guides/virtual-instances.html), as it also works with the recursor, even if it's not documented.

Adapt the configuration to your environment. You'll probably have to change `local-address` and `local-port` (127.0.0.1 and 5353 in this example).

PowerDNS recursor should read the LUA file:

```lua
lua-dns-script=/etc/powerdns/geoip-info.lua
```

The script uses the `preresolve` interception function. If you want to learn more, it's very well [documented](https://docs.powerdns.com/recursor/lua-scripting/hooks.html).

Before you configure `geoip-info.lua`, please make sure to test the performance impact of the script in your environment.

### MaxMind GeoIP

You need both `GeoLite2 Country` and `GeoLite2 ASN` database files (`mmdb`). These are available with a free MaxMind suscription. Please read the [documentation](https://www.maxmind.com/en/geoip2-databases) to double check if you need a commercial license.

The LUA script expects to find these files at:

```bash
  /usr/local/GeoLite2-Country.mmdb
  /usr/local/GeoLite2-ASN.mmdb
```

Feel free to change them to suit your needs.

### LUA libraries

The LUA script uses [this](https://github.com/daurnimator/mmdblua) system library to read GeoIP data. Please follow the installation instructions and make sure you're running at least the `0.2` version of the library.

There are more LUA libraries available that can read mmdb data, and the script is easy to change in case you want to use another one.

## Examples

Let's say we want to see data about `193.0.6.139`. This is the A record for `www.ripe.net`.

- Get all the data (autonomous system number|IP address|country|continent|registered country|Autonomous system organization)

  ```bash
  # dig -t txt 139.6.0.193.rbl.example.com +short
  "3333|193.0.6.139/32|NL|EU|NL|Reseaux IP Europeens Network Coordination Centre (RIPE NCC)"

  # Same information using the direct IP address
  # dig -t txt 193.0.6.139.direct.rbl.example.com +short
  "3333|193.0.6.139/32|NL|EU|NL|Reseaux IP Europeens Network Coordination Centre (RIPE NCC)"
  ```

- Get individual records

  ```bash
  # dig -t txt 139.6.0.193.asn.rbl.example.com +short
  "3333"

  # dig -t txt 139.6.0.193.country.rbl.example.com +short
  "NL"

  # dig -t txt 139.6.0.193.continent.rbl.example.com +short
  "EU"
  ```