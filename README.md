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
## Installation
```bash
docker pull microsoft/mssql-server-linux:2017-latest

docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=yourStrong(!)Password' -e 'MSSQL_PID=Express' -p 1433:1433 -d microsoft/mssql-server-linux:latest
```
You can learn more about it here:

https://hub.docker.com/r/microsoft/mssql-server-linux/

## Connecting
In order to connect to MSSQL Server Console, type:
```bash
mssql -u sa -p $PASS
```

or you can just use your IDE and as a server type "localhost" with port 1433. Username is "sa" (admin). 

## Authors

* **Tomasz Czajęcki** - [GitHub Profile](https://github.com/Tchayen)
* **Marcin Aman** - [GitHub Profile](https://github.com/MarcinAman)

## License

Feel free to use this project in your appliactions, but we do not take any responsibity for the code.
