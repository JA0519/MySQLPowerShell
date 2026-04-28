# MySQL PowerShell
This module makes it easy to execute MySQL Commands from within PowerShell on Windows systems.

## Dependencies
There are a couple of dependencies that need to be installed before you can use this module:
1. [MySQL .NET Connector](https://dev.mysql.com/downloads/connector/net/)
2. [Bouncy Castle .NET](https://www.bouncycastle.org/download/bouncy-castle-c/#latest) (You need to extract the BouncyCastle.Cryptography.dll to a location that is accessible by the script)
3. [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)

## Installation
Follow the steps below to install the module
1. Download the script and extract the `MySQLPowerShell` folder into one of the PowerShell module locations (These can be found by running `$Env:PSModulePath -split (';')` from within PowerShell)
2. Open a new PowerShell window and type `Get-Module -ListAvailable`. This will show all of the modules you have installed, within this list should be one titled `MySQL PowerShell`. If so, the module has been installed successfully.

## Additional Configuration

### SSL Configuration
 [!IMPORTANT]
 Using SSL is strongly advised if this module is going to be used in a production environment. 

The steps below will walk you through how to configure MySQL & this module to use SSL. The example below is done in a domain using Active Directory Certificate Services, it will be slightly different if you're are using a different certification authority.

1. Open the `Certification Authority` RSAT tool and connect to your CA
2. Right click the `Certificate Templates` folder and select `Manage`
3. You need to create two certificates, one for the MySQL server and one for the client. In this example, we'll start with the server, right click the `Web Server` template and select `Duplicate`.
    - Change `Certification Authority` & `Certificate Recipient` to the version of Windows that matches your Active Directory Forest
    - On the `General` tab, give the certificate a name, in this example, we'll use MySQL Server
    - Go to the `Request Handling` tab and tick the `Allow private key to be exported` box
    - Then, go to the `Security` tab and give the server MySQL is hosted on Read and Enroll permissions to the template
    - Go to the `Extensions` tab and select the `Application Policies` option. When you've done that you should only see `Server Authentication` in the `Description of Application Policies` box. If you see others, click `Edit`, select the other ones and click `Remove` until you only have `Server Authentication`
    - Then click `Apply` and `Ok`, this will create the certificate template in AD CS. We now need to publish it so our server hosting MySQL can create a certificate using that template
    - Close the `Certificate Templates` console and go back to the `Certification Authority` window, right click the `Certificate Templates` folder and select `New > Certificate Template to Issue`
    - Select the certificate that you have just created and select `Ok`. This will publish the template so that clients can create certificates using that template. The server certificate has now been created, it may take several minutes for it to be visible to the server.
4. Now that the server certificate has been created, you need to create one for the client.
    - Right click the `Workstation Authentication` template and select `Duplicate Template`
    - Change the `Certification Authority` to the version of Windows on your domain controllers
    - Change the `Certificate Recipient` to Windows 10 / Server 2016
    - On the `General` tab, give the certificate a name, in this example, we'll use MySQL Client
    - Go to the `Request Handling` tab tick the `Allow private key to be exported` box
    - Then go the `Security` tab and give the client you want to use as the MySQL client permissions to Read and Enroll permissions.
    - Go to the `Extensions` tab and select the `Application Policies` option. When you've done that, you should only see `Client Authentication` in the `Description of Application Policies` box. If you see others, click `Edit` and select the other ones and click `Remove` until you only have `Client Authentication`
    - Then click `Apply` and `Ok`, this will create the certificate template in AD CS. We now need to publish it so our clients can create a certificate using that template.
    - Close the `Certificate Templates` console and go back to the `Certification Authority` window, right click the `Certificate Templates` folder and select `New > Certificate Template to Issue`
    - Select the certificate that you have just created and select `Ok`. This will publish the template so that clients can create certificates using that template. The client certificate has now been created, it may take several minutes for it to be visible to the clients.
5. Once you've created the certificates, you now need to create one on the server hosting MySQL.
    - On the server hosting MySQL, open `certlm.msc`
    - Go to `Personal > Certificates`, right click the `certificates` folder and select `All Tasks > Request New Certificate > Next > Next > Select More Information is required to enroll for this certificate under the MySQL Server template`
        - Go to the `Subject` tab and change the `Subject name` type to `Common Name` and enter the FQDN of your server
        - Under the `Alternative name`, change `Directory Name` to `DNS` and enter the FQDN of your server
        - Select `Ok` and select `Enroll`
6. The next thing to do is to export the CA certificate. This is so MySQL can trust the certificates that are created.
    - In `certlm.msc`, go to `Trusted Root Certification Authorities`, right click your AD CA certificate and choose `All Tasks > Export`
    - Click `Next` and on the Certificate Export Wizard page, change the format to base-64 encoded X.509 (Cer)
7. Now the certificate has been created for the MySQL Server, you need to create one for the MySQL client. In this example, the client machine is also the same machine as the server. Both sets of certificates still need to be created if this is your case as well.
    - Open `certlm.msc`
    - Go to `Personal > Certificates`, right click the `certificates` folder and select `All Tasks > Request New Certificate > Next > Next > Select MySQL Client > Click Enroll`. As this is only a client certificate, we don't need to configure any other options.
8. You now need to export the MySQL Server certificate so that your MySQL Server can use it.
    - In `certlm.msc` right click the MySQL Server certificate and choose `All Tasks > Export`
    - In the `Certificate Export Wizard` click `Next`
    - On the `Export Private Key page`, select `Yes, Export the private key`
    - Leave the `Export File Format` options as their default values and click `Next`
    - Give the exported certificate a password and change the encryption to `AES256-SHA256`. The password you sent doesn't really matter as the exported certificate will be deleted at the end of the installation process.
    - Export the certificate to a location of your choice
9. MySQL Server doesn't support .pfx files which means you have to convert the exported certificate into multiple .pem files. This can be achieved by following the steps below.
    - Open a CMD or PowerShell window and run the below commands:
        - `openssl pkcs12 -in [Name & Extension of server certificate] -out server.pem -nodes`
        - `openssl pkey -in [Name & Extension of pem file] -out server-key.pem`
        - `openssl x509  -in [Name & Extension of pem file] -out server-cert.pem`
10. Once you've converted the certificates into a .pem format, export them to a folder of your choice, it just needs to be one that the MySQL server can access.
11. Open the `my.ini` file in `C:\ProgramData\MySQL\MySQL Server [Version]` and add the below settings to the [mysqld] section (You may need to create it if it doesn't already exist). Once you've done that, save the file and restart the MySQL Service.
```
[mysqld]
ssl-ca="C:/Path/To/CA/Certificate.pem"
ssl-cert="C:/Path/To/ServerCert.pem"
ssl-key="C:/Path/To/ServerKey.pem"
require_secure_transport = ON
```
12. Once the service has started, you can now delete the server certificate .pfx file as this is no longer needed.

Once the steps above have been completed, the configuration for SSL in MySQL has been completed. You don't need to configure any client certificates as the module will look in the computers certificate store for one that it can use.

### Suggested MySQL Modifications
#### User Permissions
One suggestion which is recommended to strengthen the security of your MySQL server is to only allows users to authenticate if a valid certificate is present. You can do this by running the below queries on the MySQL server.
```
ALTER USER 'username'@'%' IDENTIFIED BY '';
ALTER USER 'username'@'%' REQUIRE X509;
```