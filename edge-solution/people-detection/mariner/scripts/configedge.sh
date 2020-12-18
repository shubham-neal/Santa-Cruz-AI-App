set -e

configFile=/etc/iotedge/config.yaml

if [ -z "$1" ]
then
    echo "$(date) No connection string supplied. Exiting." >&2
    exit 1
fi

connectionString=$1

# wait to set connection string until config.yaml is available
until [ -f $configFile ]
do
    sleep 5
done

echo "$(date) Setting connection string"
sed -i "s#\(device_connection_string: \).*#\1\"$connectionString\"#g" $configFile
sudo systemctl restart iotedge

echo " $(date) Connection string set to $connectionString"