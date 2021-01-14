# Nginx reverse proxy

```
terraform apply

dm create --driver generic --generic-ip-address=$(to -json ec2 | jq '.vm.public_ip' | tr -d '"') --generic-ssh-key=$(to -json ec2 | jq '.key.filename' | tr -d '"') --generic-ssh-user ubuntu nginx

sed -i '' 's/server_name [^;]*;/server_name '$(to -json ec2 | jq '.vm.public_ip' | tr -d '"')';/' ../nginx.vh.default.conf

cd ..

eval $(dm env nginx)

docker-compose up -d
```

```
dm ip nginx
```