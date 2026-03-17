# Instalación del driver ODBC en Ubuntu 24.04

Instrucciones para conectar Harbour a SQL Server desde Ubuntu 24.04 / WSL.

---

## 1. Importar llave GPG de Microsoft
```bash
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
  sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
```

---

## 2. Agregar repositorio
```bash
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] \
https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | \
sudo tee /etc/apt/sources.list.d/mssql-release.list
```

> Ubuntu 24.04 usa el repositorio `jammy` (22.04) de Microsoft porque aún
> no existe paquete nativo para Noble. En la práctica funciona sin problemas.

---

## 3. Instalar driver y herramientas
```bash
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17 unixodbc unixodbc-dev
```

Para tener también `sqlcmd` disponible en la terminal:
```bash
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc
```

---

## 4. Verificar drivers instalados
```bash
odbcinst -q -d
```

Debe mostrar al menos:
```
[ODBC Driver 17 for SQL Server]
```

---

## 5. Obtener la IP del host Windows desde WSL

SQL Server corre en Windows. Desde WSL no se llega por `localhost` sino
por la IP del host Windows, que se obtiene con:
```bash
ip route show default | awk '{print $3}'
```

---

## 6. Probar la conexión
```bash
sqlcmd -S $(ip route show default | awk '{print $3}')\SQLEXPRESS \
  -U TU_USUARIO -P TU_PASSWORD -Q "SELECT @@VERSION"
```

Si responde con la versión de SQL Server la conexión está lista.