# Databases course
Project for databases course. AGH University of science and Technology. Winter 2017.

## Notes
- Password must contain some special characters.
- Use Kitematic to view MSSQL error log, sometimes really useful.
- Don't forget about `USE #{dbname}` when creating tables in mssql console.

## Notable defaults
```
-port 1433
-host 127.0.0.1
-username sa
```

## Credentials used by me
```bash
$CONT = mssql # container name
$PASS = P@ssw0rd # password for user 'sa'
```
## Installation
```bash
docker pull microsoft/mssql-server-linux:2017-latest

docker run -d --name $CONT -e 'ACCEPT_EULA=Y' -e "SA_PASSWORD=$PASS" -e 'MSSQL_PID=Developer' -p 1433:1433 microsoft/mssql-server-linux:2017-latest
```
You can learn more about it here:

https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker

## Connecting
In order to connect to MSSQL Server Console, type:
```bash
mssql -u sa -p $PASS
```

or you can just use your IDE and as a server type "localhost". 
