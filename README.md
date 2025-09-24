# manage_tns

The purpose of this script is to simplify Oracle database name service entry management in an LDAP-based directory service

## Installation

*The instructions are very simple. Download and use the script on any Linux system.

## Usage

NAME
     manage_tns.sh [subcommand] -n <alias> [options]

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

     Show database entry
        manage_tns.sh show -n <alias>

     List database entries
        manage_tns.sh list

OPTIONS
     The following options are supported:

     -z                 Show debug output

     -n <alias>         Database alias name
                        Default: tns1

     -s <svc_name>      Database service name
                        Default: tns1

     -c <string>        Custom connect string

     -h <ds_host>       Directory server fully qualified host name
                        Default: tns1.sub10241351260.odswest.oraclevcn.com

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
                        Default: tns1.sub10241351260.odswest.oraclevcn.com

     --dbport <port>    Database port number
                        Default: 1521

     --subject <DN>      Certificate subject DN
                        Default: tns1.sub10241351260.odswest.oraclevcn.com

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

*Describe any included examples or provide a link to a demo/tutorial*

## Help

*Inform users on where to get help or how to receive official support from Oracle (if applicable)*

## Contributing

*If your project has specific contribution requirements, update the CONTRIBUTING.md file to ensure those requirements are clearly explained*

This project welcomes contributions from the community. Before submitting a pull request, please [review our contribution guide](./CONTRIBUTING.md)

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
