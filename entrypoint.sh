#!/bin/bash -e
if [ -z ${EXTERNAL_IP} ];
then
  echo "External IP not set - trying to get IP by myself"
  export EXTERNAL_IP=$(curl -f icanhazip.com)
fi

if [ -z ${DNSDIST_WEBSERVER_PASSWORD} ];
then
  echo "Dnsdist webserver password not set - generating one"
  export DNSDIST_WEBSERVER_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
  echo "Generated WebServer Password: $DNSDIST_WEBSERVER_PASSWORD"
fi

if [ -z ${DNSDIST_WEBSERVER_API_KEY} ];
then
  echo "Dnsdist webserver api key not set - generating one"
  export DNSDIST_WEBSERVER_API_KEY=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
  echo "Generated WebServer API Key: $DNSDIST_WEBSERVER_API_KEY"
fi
ALLOWED_CLIENTS="127.0.0.1, 0.0.0.0"
if [ ! -z ${ALLOWED_CLIENTS_FILE} ];
then
  if [ -f ${ALLOWED_CLIENTS_FILE} ];
  then
    chown dnsdist:dnsdist $ALLOWED_CLIENTS_FILE
    ln -s $ALLOWED_CLIENTS_FILE /etc/dnsdist/allowedClients.acl
  else
    echo "[ERROR] ALLOWED_CLIENTS_FILE is set but file does not exists or is not accessible!"
  fi
else
  IFS=', ' read -ra array <<< "$ALLOWED_CLIENTS"
  printf '%s\n' "${array[@]}" > /etc/dnsdist/allowedClients.acl
fi

sed -i "s/DNSDIST_BIND_IP/$DNSDIST_BIND_IP/" /etc/dnsdist/dnsdist_all.conf && \
sed -i "s/EXTERNAL_IP/$EXTERNAL_IP/" /etc/dnsdist/dnsdist_all.conf && \
sed -i "s/DNSDIST_WEBSERVER_PASSWORD/$DNSDIST_WEBSERVER_PASSWORD/" /etc/dnsdist/dnsdist_all.conf && \
sed -i "s/DNSDIST_WEBSERVER_API_KEY/$DNSDIST_WEBSERVER_API_KEY/" /etc/dnsdist/dnsdist_all.conf && \
sed -i "s/DNSDIST_WEBSERVER_NETWORKS_ACL/$DNSDIST_WEBSERVER_NETWORKS_ACL/" /etc/dnsdist/dnsdist_all.conf && \
sed -i "s/DNSDIST_UPSTREAM_CHECK_INTERVAL/$DNSDIST_UPSTREAM_CHECK_INTERVAL/" /etc/dnsdist/dnsdist_all.conf

sed -i "s/DNSDIST_BIND_IP/$DNSDIST_BIND_IP/" /etc/dnsdist/dnsdist.conf && \
sed -i "s/EXTERNAL_IP/$EXTERNAL_IP/" /etc/dnsdist/dnsdist.conf && \
sed -i "s/DNSDIST_WEBSERVER_PASSWORD/$DNSDIST_WEBSERVER_PASSWORD/" /etc/dnsdist/dnsdist.conf && \
sed -i "s/DNSDIST_WEBSERVER_API_KEY/$DNSDIST_WEBSERVER_API_KEY/" /etc/dnsdist/dnsdist.conf && \
sed -i "s/DNSDIST_WEBSERVER_NETWORKS_ACL/$DNSDIST_WEBSERVER_NETWORKS_ACL/" /etc/dnsdist/dnsdist.conf && \
sed -i "s/DNSDIST_UPSTREAM_CHECK_INTERVAL/$DNSDIST_UPSTREAM_CHECK_INTERVAL/" /etc/dnsdist/dnsdist.conf

echo "Starting DNSDist..."

chown -R dnsdist:dnsdist /etc/dnsdist/

if [ ${SPOOF_ALL_DOMAINS} == "true" ];
then
/usr/bin/dnsdist -C /etc/dnsdist/dnsdist_all.conf --supervised --disable-syslog --uid dnsdist --gid dnsdist &
else
/usr/bin/dnsdist -C /etc/dnsdist/dnsdist.conf --supervised --disable-syslog --uid dnsdist --gid dnsdist &
fi

echo "Starting sniproxy"
/usr/local/bin/sniproxy --httpPort 80 --httpsPort 443 --allDomains --dnsPort 5353 --publicIP $EXTERNAL_IP &
echo "[INFO] Using $EXTERNAL_IP - Point your DNS settings to this address"
wait -n
