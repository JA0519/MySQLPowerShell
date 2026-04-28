function Invoke-MySQLConnection{
    <#
    .SYNOPSIS
    Connects to MySQL and runs queries against the specified database
    
    .DESCRIPTION
    Connects to MySQL and runs queries against the specified database
    
    .PARAMETER Connection
    The connection object that contains the details used to connect to a MySQL database

    The connection object should be passed into the parameter like this:
        Connecting with SSL      - $Connection.ConnectionString = "SERVER=$Server;DATABASE=$Database;USER=$Username;Certificate Store Location=LocalMachine;SslMode=Required"
        Connecting with Password - $Connection.ConnectionString = "SERVER=$Server;DATABASE=$Database;USER=$Username;PWD=$Password"
    
    .EXAMPLE
    Invoke-MySQLConnection -Connection $Connection
    
    .NOTES
    For ease of use this function should be used along with the Invoke-MySQLQuery function
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [MySql.Data.MySqlClient.MySqlConnection]$Connection
    )

    $Connection.Open() # Open the connection to the MySQL Server
    if($Connection.State -eq "Open"){
        $sql = New-Object MySql.Data.MySqlClient.MySqlCommand
        $sql.Connection = $Connection
        $sql.CommandText = $Query
        $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($sql)
        $dataSet = New-Object System.Data.DataSet
        $null = $dataAdapter.Fill($dataSet) # Assign this to null so the number of rows returned isn't outputted to the variable
        return $dataSet.tables[0] # Return the results of the query
        $Connection.Close() # Closes the connection to the database once we're done with it
    }
    else{
        Write-Error "Failed to connect to $($Connection.Database) on $($Connection.DataSource)"
    }
}

function Invoke-MySQLQuery{
    <#
    .SYNOPSIS
    An interface that allows execution of MySQL queries from PowerShell on Windows systems
    
    .DESCRIPTION
    An interface that allows execution of MySQL queries from PowerShell on Windows systems
    
    .PARAMETER SSL
    Specifies whether to use an SSL connection - The certificates should be configured for this before using this option

    .PARAMETER Server
    Specifies which server is hosting the MySQL Database (localhost & 127.0.0.1 are supported)

    .PARAMETER Username
    The MySQL User account to use that is authorised to access the database

    .PARAMETER Password
    The password for the MySQL User account that is authorised to access the database. This should not be used in production as it's insecure, SSL should be used instead

    .PARAMETER Database
    The MySQL Database to run the query against

    .PARAMETER Query
    The MySQL query to run against the database
    
    .EXAMPLE
    Example using SSL      - Invoke-MySQLQuery -SSL -Server "localhost" -Username "myuser" -Database "testdatabase" -Query "SELECT * FROM testtable;"
    Example using Password - Invoke-MySQLQuery -Server "localhost" -Username "myuser_test" -Password "password" -Database "testdatabase" -Query "SELECT * FROM testtable;"
    
    .NOTES
    Requires the below dependencies to be installed on the system
        - MySQL .NET Connector - https://dev.mysql.com/downloads/connector/net/
        - Bouncy Castle Cyryptography - https://www.bouncycastle.org/download/bouncy-castle-c/#latest

    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$SSL,
        [Parameter(mandatory=$true)]
        [string]$Server,
        [Parameter(mandatory=$true)]
        [string]$Username,
        [Parameter()]
        [string]$Password,
        [Parameter(mandatory=$true)]
        [string]$Database,
        [Parameter(mandatory=$true)]
        [string]$Query
    )

    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.6\BouncyCastle.Cryptography.dll" # Load the DLL needed for SSL Authentication - Change this to where your DLL file is located
    [void][system.reflection.Assembly]::LoadFrom("C:\Program Files (x86)\MySQL\MySQL Connector NET 9.6\MySql.Data.dll") # Load the MySQL .NET Library - Change this to the path of the MySql.Data.dll file, this is located in the install directory of the MySQL .NET Connector
    $Connection = New-Object -TypeName MySql.Data.MySqlClient.MySqlConnection # Create a new MySQL Connection object

    if($SSL){
        $Connection.ConnectionString = "SERVER=$Server;DATABASE=$Database;USER=$Username;Certificate Store Location=LocalMachine;SslMode=Required" # Connect to MySQL using the parameters passed through from the pipeline
        Invoke-MySQLConnection -Connection $Connection
    }
    elseif(!($SSL)){
        Write-Warning "You are connected using a password, this is insecure and should not be used in a production environment"
        $Connection.ConnectionString = "SERVER=$Server;DATABASE=$Database;USER=$Username;PWD=$Password" # Connect to MySQL using the parameters passed through from the pipeline
        Invoke-MySQLConnection -Connection $Connection
    }
}