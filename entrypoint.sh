#!/bin/bash -e
if [ -z "${EXTERNAL_IP}" ];
then
  echo "SmartDNS IP not set - trying to get IP from wg0.conf"
  EXTERNAL_IP=$(grep -oP 'Address = \K[^ /]+' /etc/wireguard/wg0.conf)
  export EXTERNAL_IP
fi

if [ -z "${DNSDIST_WEBSERVER_PASSWORD}" ];
then
  echo "Dnsdist webserver password not set - generating one"
  DNSDIST_WEBSERVER_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
  export DNSDIST_WEBSERVER_PASSWORD
  echo "Generated WebServer Password: $DNSDIST_WEBSERVER_PASSWORD"
fi

if [ -z "${DNSDIST_WEBSERVER_API_KEY}" ];
then
  echo "Dnsdist webserver api key not set - generating one"
  DNSDIST_WEBSERVER_API_KEY=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
  export DNSDIST_WEBSERVER_API_KEY
  echo "Generated WebServer API Key: $DNSDIST_WEBSERVER_API_KEY"
fi

if [ -z "${ALLOWED_CLIENTS}" ];
then
  echo "ALLOWED_CLIENTS is not set, using default subnet from wg0.conf"
  ALLOWED_CLIENTS=$(grep -oP 'Address = \K[^ ]+' /etc/wireguard/wg0.conf)
else
  IFS=', ' read -ra array <<< "$ALLOWED_CLIENTS"
  printf '%s\n' "${array[@]}" > /etc/dnsdist/allowedClients.acl
fi

if [ -f "/etc/dnsdist/allowedClients.acl" ];
then
  while IFS= read -r line
  do
    echo "$line,allow" >> /etc/sniproxy/allowedClients.acl
  done < "/etc/dnsdist/allowedClients.acl"
fi

echo "[Wireguard] Starting wireguard server"
wg-quick up wg0

echo "Generating DNSDist Configs..."
/bin/bash /etc/dnsdist/dnsdist.conf.template > /etc/dnsdist/dnsdist.conf

echo "Starting DNSDist..."
chown -R dnsdist:dnsdist /etc/dnsdist/
/usr/bin/dnsdist -C /etc/dnsdist/dnsdist.conf --supervised --disable-syslog --uid dnsdist --gid dnsdist &

echo "Starting sniproxy"
/usr/local/bin/sniproxy --config "/etc/sniproxy/config.yaml" &
echo "[INFO] Using $EXTERNAL_IP - Point your DNS settings to this address"

wait -n
