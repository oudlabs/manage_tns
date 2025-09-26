# manage_tns

The purpose of this script is to simplify Oracle database name service entry management in an LDAP-based directory service

## Installation

The installation instructions are very simple. Download and use the script and use on any Linux system.

## Usage

NAME
     manage_tns.sh [subcommand] -n \<alias\> [options]

SUBCOMMANDS

        register      Register a database

        unregister    Unregister a database

        show          Show the database TNS entry

        list          List all registered database

SYNOPSIS

     Register database with default connect string
        manage_tns.sh register -n <alias>

     Register database with custom connect string
        manage_tns.sh register -n <alias> -c "<string>"

     Register database with Entra ID integration
        manage_tns.sh register -n <alias> --method interactive --tenantid <id> --clientid <id> --serveruri <uri>

     Unregister database
        manage_tns.sh unregister -n <alias>

     List database entries
        manage_tns.sh list

     Show database entry
        manage_tns.sh show -n <alias>

     Show database entry connect string
        manage_tns.sh showcs -n <alias>


OPTIONS

     The following options are supported:

     -z                 Show debug output

     -n <alias>         Database alias name
                        Default: tns1

     -s <svc_name>      Database service name
                        Default: tns1

     -c <string>        Custom connect string

     -h <ds_host>       Directory server fully qualified host name
                        Default: tns1.example.com

     -p <ldaps_port>    Directory server secure (ldaps) port number
                        Default: 10636

     -D <userdn>        Distinguished name of TNS admin user
                        Default: cn=eusadmin,ou=EUSAdmins,cn=oracleContext

     -j <pw_file>       Password file of TNS admin user

     --sid <SID>        ORACLE_SID
                        Default: tns1

     --base <dir>       ORACLE_BASE
                        Default: /u01/app/oracle/19c

     --home <dir>       ORACLE_HOME
                        Default: /u01/app/oracle/19c/dbhome_1

     --dbhost <host>    Fully qualified database host name 
                        Default: tns1.example.com

     --dbport <port>    Database port number
                        Default: 1521

     --subject <DN>      Certificate subject DN
                        Default: tns1.example.com

     --wallet <wallet>  Wallet location
                        Default: SYSTEM

     --dbproto <proto>  Protocol of TCP or TCPS
                        Default: TCP

     --svctype <type>   Service handler type
                        Default: DEDICATED
                        Options:
                           DEDICATED to specify whether client requests be served by dedicated server
                           SHARED to specify whether client request be served by shared server
                           POOLED to get a connection from the connection pool if database resident 
                             connection pooling is enabled on the server

Entra ID Integration Options

     --method <method>  Authentication method
                        Default: interactive
                        Options:
                           interactive - Browser to Entra ID login pops up locally
                           passthrough - Entra ID login URL and token provided inline
                                         to be opened and completed in separate browser
                           service - Service account

     --tenantid <id>    Entra ID tenant ID

     --clientid <id>    Entra ID web app client ID of registered Oracle database client

     --serveruri <uri>  Entra ID web app ID URI of registered Oracle database server


## Examples

**Example 1: Register a database**  
$ /u01/manage_tns.sh.sh register -n mydb --suffix "dc=example,dc=com"
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory as cn=eusadmin,ou=EUSAdmins,cn=oracleContext  
Enter directory service TNS admin user's password: *********  
Register database mydb  
Database registration completed successfully  


**Example 2: Register a database that includes Entra ID integration configuration**  
$ /u01/manage_tns.sh register -n mypdb --suffix "dc=example,dc=com" --method interactive --tenantid 7f4c6e3e-a1e0-43fe-14c5-c2f051a0a3a1 --clientid e5124a85-ac3e-14a4-f2ca-1ad635cf781a --serveruri "https://dbauthdemo.com/16736175-ca41-8f33-af0d-4616ade17621"  
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory as cn=eusadmin,ou=EUSAdmins,cn=oracleContext  
Enter directory service TNS admin user's password: *********  
Register database mypdb  
Database registration completed successfully  


**Example 3: List registered databases**  
$ /u01/manage_tns.sh list --suffix "dc=example,dc=com"
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory service anonymously  
List registered databases  
mydb
mypdb

**Example 4: Show specific registered database**  
$ /u01/manage_tns.sh show -n mypdb --suffix "dc=example,dc=com" 
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory service anonymously  
Show database mypdb  
dn: cn=mypdb,cn=OracleContext,dc=example,dc=com  
cn: mypdb  
objectClass: orclApplicationEntity  
objectClass: orclDBServer  
objectClass: orclService  
objectClass: top  
objectClass: orclDBServer_92  
orclDBGlobalName: mypdb  
orclNetDescName: 000:cn=DESCRIPTION_0  
orclNetDescString: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=tns1.example.com)(PORT=1521))(SECURITY=(SSL_SERVER_DN_MATCH=TRUE)(WALLET_LOCATION=SYSTEM)(TOKEN_AUTH=AZURE_INTERACTIVE)(TENANT_ID=7f4c6e3e-a1e0-43fe-14c5-c2f051a0a3a1)(AZURE_DB_APP_ID_URI=https://dbauthdemo.com/16736175-ca41-8f33-af0d-4616ade17621)(CLIENT_ID=e5124a85-ac3e-14a4-f2ca-1ad635cf781a))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=mypdb)))  
orclOracleHome: /dbhome_1  
orclServiceType: DB  
orclSid: mypdb  
orclSystemName: tns1.example.com  
orclVersion: 121000  

**Example 5: Un-register a database**  
$ /u01/manage_tns.sh.sh unregister -n mydb --suffix "dc=example,dc=com"
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory as cn=eusadmin,ou=EUSAdmins,cn=oracleContext  
Enter directory service TNS admin user's password: *********  
Unregister database mydb  
Database unregistration completed successfully  

**Example 6: List registered databases**  
manage_tns.sh list --suffix "dc=example,dc=com"
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory service anonymously  
List registered databases  

cn=mypdb,cn=OracleContext,dc=example,dc=com  
orclNetDescString: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=tns1.example.com)(PORT=1521))(SECURITY=(SSL_SERVER_DN_MATCH=TRUE)(WALLET_LOCATION=SYSTEM)(TOKEN_AUTH=AZURE_INTERACTIVE)(TENANT_ID=7f4c6e3e-a1e0-43fe-14c5-c2f051a0a3a1)(AZURE_DB_APP_ID_URI=https://dbauthdemo.com/16736175-ca41-8f33-af0d-4616ade17621)(CLIENT_ID=e5124a85-ac3e-14a4-f2ca-1ad635cf781a))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=mypdb)))  

  
**Example 7: Register database with TCPS**  
$ /u01/manage_tns.sh register -n pdb3 --suffix "dc=example,dc=com" --dbhost pdb3.example.com --dbport 2484 --dbproto TCPS -s pdb3.example.com  
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory as cn=eusadmin,ou=EUSAdmins,cn=oracleContext  
Enter directory service TNS admin user's password: *********  
Register database tns3  
Database registration completed successfully  
  
 
**Example 8: Show database pdb3**  
$ /u01/manage_tns.sh show -n pdb3 --suffix "dc=example,dc=com" 
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory service anonymously  
Show database pdb3  
dn: cn=pdb3,cn=OracleContext,dc=example,dc=com  
cn: pdb3  
objectClass: orclApplicationEntity  
objectClass: orclDBServer  
objectClass: orclService  
objectClass: top  
objectClass: orclDBServer_92  
orclDBGlobalName: pdb3  
orclNetDescName: 000:cn=DESCRIPTION_0  
orclNetDescString: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=pdb3.example.com)(PORT=2484))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=pdb3.example.com)))  
orclOracleHome: /dbhome_1  
orclServiceType: DB  
orclSid: pdb3  
orclSystemName: pdb3.example.com  
orclVersion: 121000  
  
**Example 9: Register database with custom connect string**  
$ /u01/manage_tns.sh register -n pdb4 --suffix "dc=example,dc=com" -c "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=pdb4.example.com)(PORT=2484))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=pdb4.example.com)))"  
Directory Server: ldaps://tns1.example.com:10636  
User: Loging into directory as cn=eusadmin,ou=EUSAdmins,cn=oracleContext  
Enter directory service TNS admin user's password: *********  
Register database pdb4  
Database registration completed successfully  
  

## Security

Please consult the [security guide](./SECURITY.md) for our responsible security vulnerability disclosure process

## License

*The correct copyright notice format for both documentation and software is*
    "Copyright (c) [year,] year Oracle and/or its affiliates."
*You must include the year the content was first released (on any platform) and the most recent year in which it was revised*

Copyright (c) 2023 Oracle and/or its affiliates.

*Replace this statement if your project is not licensed under the UPL*

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.
