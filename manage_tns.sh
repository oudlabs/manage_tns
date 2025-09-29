#!/bin/bash
###############################################################################
# Copyright (c) 2025 Oracle and/or its affiliates.
#
# The manage_tns.sh script provides a means by which to manage TNS entries
# in an LDAP-based directory service using python-ldap module
#
# The manage_tns.sh script is open source and distributed under Universal 
# Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl/.
###############################################################################

###############################################################################
# Usage
###############################################################################
showUsage() {
   msg="$1"
   if [ -n "${msg}" ];then echo -e "Error: ${msg}\n";fi

cat <<EOUSAGE
NAME
     ${cmd} [subcommand] -n <alias> --suffix <suffix> [options]

DESCRIPTION
     The purpose of this script is to simplify TNS entry management in a
     LDAP-based directory service

     Subcommands:
        register      Register a database

        unregister    Unregister a database

        list          List all registered databases

        listcs        List all registered databases with connect string

        listldif      List all registered databases in full LDIF format

        show          Show the database TNS entry

        showcs        Show the database TNS entry connect string

        export        Export DS entries to a tnsnames.ora file

        exportcman    Export DS entries to a tnsnames.ora file for CMAN setup

        exportmsie    Export DS entries to a tnsnames.ora file for MSIE aliases

        load          Load all entries from a tnsnames.ora file into DS

SYNOPSIS

     Register database with default connect string
        ${cmd} register -n <alias> --suffix <suffix>

     Register database with custom connect string
        ${cmd} register -n <alias> --suffix <suffix> -c "<string>"

     Register database with Entra ID integration
        ${cmd} register -n <alias> --suffix <suffix> --method interactive --tenantid <id> --clientid <id> --serveruri <uri>

     Unregister database
        ${cmd} unregister -n <alias> --suffix <suffix>

     Show database entry
        ${cmd} show -n <alias> --suffix <suffix>

     Show database entry with formatted connect string
        ${cmd} show -n <alias> --suffix <suffix>

     List database entries
        ${cmd} list --suffix <suffix>

     List database entries with connect string
        ${cmd} listcs --suffix <suffix>

     List database entries in full LDIF format
        ${cmd} listldif --suffix <suffix>

     Export all entries from the directory service to a tnsnames.ora file
        ${cmd} export --suffix <suffix> -f <tnsnames_file>

     Export all entries from the directory service to a tnsnames.ora file
     for use in Oracle Connection Manager proxy architecture where the
     cman_host can be an un-qualified host, fully qualified host, or IP 
     address of the actual host or a load balancer VIP. Note for TLS
     connections, the certificate chain of the database clients will need
     to be for the CMAN host, not the target database host.
        ${cmd} exportcman --suffix <suffix> -chost <cman_host> -f <tnsnames_file>

     Export all entries from the directory service to a tnsnames.ora where
     entires that do not already contain MSIE properties are tagged with
     <entry>_MSIE or whatever tag name that you specify with --tag <tag>.
        ${cmd} exportmsie --suffix <suffix> -f <tnsnames_file> --tag <tag>

     Load all entries from a tnsnames.ora file into the directory service
        ${cmd} load --suffix <suffix> -f <tnsnames_file>


OPTIONS
     The following options are supported:

     -z                 Show debug output

     -n <alias>         Database alias name
                        Default: ${localH}

     --suffix <suffix>  Directory server naming context (a.k.a. base suffix)

     -s <svc_name>      Database service name
                        Default: ${localH}

     -c <string>        Custom connect string

     -h <ds_host>       Directory server fully qualified host name
                        Default: $(hostname -f)

     -p <ldaps_port>    Directory server secure (ldaps) port number
                        Default: 10636

     -D <userdn>        Distinguished name of TNS admin user
                        Default: cn=eusadmin,ou=EUSAdmins,cn=oracleContext

     -j <pw_file>       Password file of TNS admin user

     -f <tns_file>      tnsnames.ora file

     --sid <SID>        ORACLE_SID
                        Default: ${localH}

     --base <dir>       ORACLE_BASE
                        Default: /u01/app/oracle/19c

     --home <dir>       ORACLE_HOME
                        Default: /u01/app/oracle/19c/dbhome_1

     --dbhost <host>    Fully qualified database host name 
                        Default: ${localHost}

     --dbport <port>    Database port number
                        Default: 1521

     --subject <DN>      Certificate subject DN
                        Default: ${localHost}

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

     --chost <host>     Connection Manager Host

     --tag <name>       Tag for duplicate name service entries
                        Default: MSIE

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

EOUSAGE

   exit 1
}

##############################################################################
# Lookup OS
##############################################################################
lookupos() {
   # Determine Operating System
   os=$(uname -s 2> /dev/null)
   osv=$(uname -r 2> /dev/null)
   arch=$(uname -i 2> /dev/null)
   osn=''
   olv=''

   # Set osVersion
   case ${os} in
      'Linux') omc_host_type='omc_host_linux';agentOsName='linux.x64'
               osn='linux'
               if [ -n "$(grep -i Tikanga /etc/redhat-release 2> /dev/null)" ]
               then
                  osVersion="OEL5"
                  olv=5
                  if [ "${sub_cmd}" == 'setup' ];then ipv4=$(getent ahostsv4 ${agentHost}|grep STREAM | awk '{ print $1 }');fi
               elif [ -n "$(grep -i Santiago /etc/redhat-release 2> /dev/null)" ]
               then
                  osVersion="OL6"
                  olv=6
                  if [ "${sub_cmd}" == 'setup' ];then ipv4=$(getent ahostsv4 ${agentHost}|grep STREAM | awk '{ print $1 }');fi
               elif [ -n "$(grep -i Maipo /etc/redhat-release 2> /dev/null)" ]
               then
                  osVersion="OL7"
                  olv=7
                  if [ "${sub_cmd}" == 'setup' ];then ipv4=$(getent ahostsv4 ${agentHost}|grep STREAM | awk '{ print $1 }');fi
               elif [ -n "$(grep -i Ootpa /etc/redhat-release 2> /dev/null)" ]
               then
                  osVersion="OL8"
                  olv=8
                  if [ "${sub_cmd}" == 'setup' ];then ipv4=$(getent ahostsv4 ${agentHost}|grep STREAM | awk '{ print $1 }');fi
               elif [ -n "$(grep -i Plow /etc/redhat-release 2> /dev/null)" ]
               then
                  osVersion="OL9"
                  olv=9
                  if [ "${sub_cmd}" == 'setup' ];then ipv4=$(getent ahostsv4 ${agentHost}|grep STREAM | awk '{ print $1 }');fi
               elif [ -n "$(grep -i "Fedora release 31" /etc/redhat-release 2> /dev/null)" ]
               then
                  osVersion="Fedora31"
                  olv=f31
                  if [ "${sub_cmd}" == 'setup' ];then ipv4=$(getent ahostsv4 ${agentHost}|grep STREAM | awk '{ print $1 }');fi
               fi
               ;;
      'SunOS') omc_host_type='omc_host_solaris';agentOsName='solaris.x64'
               osn='solaris'
               ;;
   esac
}

##############################################################################
# Determine which python command to use according to operating system
##############################################################################
getPyCmd() {
   lookupos
   reqck=''
   case ${os} in
      'Linux') case ${olv} in
               5) pycmd="python";echo "RedHat/Oracle Linux version 5 is not supported.";exit 1;;
               6) pycmd="python"
                  ckssl=$(rpm -q openssl|grep openssl-|cut -d'-' -f2-|grep "^1")
                  ckpy=$(rpm -q python|grep python-|cut -d'-' -f2-|grep "^2.[6-9]")
                  ;;
               7) pycmd="python"
                  ckssl=$(rpm -q openssl|grep openssl-|cut -d'-' -f2-|grep "^1")
                  ckpy=$(rpm -q python|grep python-|cut -d'-' -f2-|grep "^2.[6-9]")
                  ;;
               '8'|'9') pycmd="python3"
                  cknsl=$(rpm -q libnsl|grep libnsl-)
                  ckssl=$(rpm -q openssl|grep openssl-|cut -d'-' -f2-|grep "^1")
                  ckpy=$(rpm -qa|grep "^python3")
                  ;;
               esac
               ;;
   esac

   if [ "${olv}" == "8" ] && [ -z "${cknsl}" ];then reqck='fail';echo "ERROR: Requisite failure: libnsl is not installed";fi
   if [ "${olv}" == "9" ] && [ -z "${cknsl}" ];then reqck='fail';echo "ERROR: Requisite failure: libnsl is not installed";fi
   if [ -z "${ckssl}" ];then reqck='fail';echo "ERROR: Requisite failure: openssl v1 or newer is not installed";fi
   if [ -z "${ckpy}" ];then reqck='fail';echo "ERROR: Requisite failure: python is not installed";fi
   if [ -n "${reqck}" ];then exit 1;fi
}

##############################################################################
# Determine which python command to use according to operating system
##############################################################################
checkPyLdap() {
   lookupos
   reqck=''
   case ${os} in
      'Linux') case ${olv} in
               5) pycmd="python";echo "RedHat/Oracle Linux version 5 is not supported.";exit 1;;
               6) pycmd="python"
                  ckpyldp=$(rpm -q python-ldap|grep python-ldap|cut -d'-' -f3-)
                  ;;
               7) pycmd="python"
                  ckpyldp=$(rpm -q python-ldap|grep python-ldap|cut -d'-' -f3-)
                  ;;
               '8'|'9') pycmd="python3"
                  ckpyldp=$(rpm -q python3-ldap|grep python3-ldap|cut -d'-' -f3-)
                  ;;
               esac
               ;;
   esac

   if [ -z "${ckpyldp}" ];then reqck='fail';echo "ERROR: Requisite failure: python ldap is not installed.";fi
   if [ -n "${reqck}" ];then exit 1;fi
}

##############################################################################
# Perform ldapsearch via ${pycmd}
##############################################################################
pyLdapSearch() {
  ldpProto="$1"
  ldpHost="$2"
  ldpPort="$3"
  ldpDN="$4"
  ldpBase="$5"
  ldpScope="$6"
  ldpFilter="$7"
  ldpPW="${bPW}"

  # Handle when desiring to search anonymously
  if [ -z "${ldpPW}" ];then ldpDN='';fi

  getPyCmd
  checkPyLdap

  case ${ldpScope} in
   'base') pyLdpScope='ldap.SCOPE_BASE';;
    'one') pyLdpScope='ldap.SCOPE_ONE';;
    'sub') pyLdpScope='ldap.SCOPE_SUBTREE';;
  esac

#/usr/bin/${pycmd} - 2>> ${pylog} <<EOPY
/usr/bin/${pycmd} - <<EOPY
import sys,ldap,ldif
sys.tracebacklimit = 0

ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)

# Set vars
binddn = "${ldpDN}"
pw = "${ldpPW}"
basedn = "${ldpBase}"
searchFilter = "${ldpFilter}"
searchAttribute = ["*","orclAci","orclEntryLevelAci"]
searchScope = ${pyLdpScope}
lw=ldif.LDIFWriter(sys.stdout,cols=100000)

# Connect to directory server
try:
   l = ldap.initialize("${ldpProto}://${ldpHost}:${ldpPort}")
   l.set_option(ldap.OPT_DEBUG_LEVEL, 255 )
   l.set_option(ldap.OPT_REFERRALS, 0)
   l.set_option(ldap.OPT_PROTOCOL_VERSION, 3)
   l.set_option(ldap.OPT_NETWORK_TIMEOUT, 10.0)
   l.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
   l.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
   l.simple_bind_s(binddn, pw)

except ldap.SERVER_DOWN:
  print("ERROR: LDAP server is unavailable.")
  exit(1)

except ldap.INVALID_CREDENTIALS:
  print("ERROR: Your username or password is incorrect.")
  exit(49)

except ldap.LDAPError as e:
  if type(e.message) == dict and e.message.has_key('desc'):
      print(e.message['desc'])
  else:
      print(e)
  l.unbind_s()
  exit(0)

# Perform search operation
try:
    ldap_result_id = l.search(basedn, searchScope, searchFilter, searchAttribute)
    result_set = []
    while 1:
        result_type, result_data = l.result(ldap_result_id, 0)
        if (result_data == []):
            break
        else:
            if result_type == ldap.RES_SEARCH_ENTRY:
                result_set.append(result_data)

            ldn=result_data[0][0]
            lc=result_data[0][1]
            lw.unparse(ldn,lc)

except ldap.NO_SUCH_OBJECT:
   print("database entry or naming context (${suffix}) does not exist.")
   l.unbind_s()
   exit(1)

except ldap.INSUFFICIENT_ACCESS:
   print("insufficent access to search.")
   l.unbind_s()
   exit(1)

#except ldap.LDAPError as e:
#    print(e.info)
#   print(e.message['result'])
#    print(e.message['info'])
#    print(e)
#   l.unbind_s()
#   exit(1)

l.unbind_s()
exit(0)
EOPY
   pyRC=$?
   if [ ${pyRC} -ne 0 ]
   then
      echo "ERROR: LDAP search failed with error ${pyRC}" >> ${pylog}
      echo "       URL: ${ldpProto}://${ldpHost}:${ldpPort}" >> ${pylog}
      echo "       BindDN: ${ldpDN}" >> ${pylog}
      echo "       Base: ${ldpBase}" >> ${pylog}
      echo "       Scope: ${ldpScope}" >> ${pylog}
      echo "       Filter: ${ldpFilter}" >> ${pylog}
   fi

   # If python log is empty, remove it
   if [ -s "${pylog}" ]
   then
      true
   else
      rm -f "${pylog}" 2> /dev/null
   fi
}

##############################################################################
# Unregister DB
##############################################################################
unregister_db() {
   checkPyLdap
   ldpProto='ldaps'
   if [ "${dbg}" == 'true' ];then set -x;fi

   dbDN=$(pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(cn=${dbAlias})"|grep "^dn: "|sed -e "s/^dn: //g")

   if [ -z "${dbDN}" ]
   then
      echo "The requested database entry does not exist."  
   else
      echo -e "Unregister database ${dbAlias}...\c"

      regdb_log="${logdir}/regdb-${now}.log"
      touch "${regdb_log}"
      chmod 0600 "${regdb_log}"

      getPyCmd
      ${pycmd} - <<EOPY
import sys,ldap,ldif, ldap.modlist as modlist
sys.tracebacklimit = 0

ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)

# Set vars
binddn = "${tnsAdmin}"
pw = "${bPW}"

# Connect to directory server
try:
   l = ldap.initialize("${ldpProto}://${dsHost}:${ldapsPort}")
   l.set_option(ldap.OPT_DEBUG_LEVEL, 255 )
   l.set_option(ldap.OPT_REFERRALS, 0)
   l.set_option(ldap.OPT_PROTOCOL_VERSION, 3)
   l.set_option(ldap.OPT_NETWORK_TIMEOUT, 10.0)
   l.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
   l.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
   l.simple_bind_s(binddn, pw)

except ldap.SERVER_DOWN:
   print("ERROR: LDAP server is unavailable.")
   exit(1)

except ldap.INVALID_CREDENTIALS:
   print("ERROR: The username or password is incorrect.")
   exit(49)

except ldap.INSUFFICIENT_ACCESS:
   print("insufficent access to remove entry ${dbAlias}.")
   l.unbind_s()
   exit(1)

except ldap.LDAPError as e:
   if type(e.message) == dict and e.message.has_key('desc'):
       print(e.message['result'])
   else:
      print(e)
   l.unbind_s()
   exit(1)

# Delete the DB entry
try:
   l.delete_s('${dbDN}')

except ldap.NO_SUCH_OBJECT:
   print("database entry or naming context (${suffix}) does not exist.")
   l.unbind_s()
   exit(1)

except ldap.LDAPError as e:
   if type(e.message) == dict and e.message.has_key('desc'):
       print(e.message['result'])
   else:
      print(e)
   l.unbind_s()
   exit(1)

print("success")

# Unbind before disconnecting
l.unbind_s()
exit(0)
EOPY
      pyRC=$?
   fi
}

##############################################################################
# Register DB
##############################################################################
register_db() {
   checkPyLdap
   ldpProto='ldaps'
   if [ "${dbg}" == 'true' ];then set -x;fi

   echo -e "Register database ${dbAlias}...\c"

   regdb_log="${logdir}/regdb-${now}.log"
   touch "${regdb_log}"
   chmod 0600 "${regdb_log}"

   getPyCmd
   ${pycmd} - <<EOPY
import sys,ldap,ldif, ldap.modlist as modlist
sys.tracebacklimit = 0

ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)

# Set vars
binddn = "${tnsAdmin}"
pw = "${bPW}"

# Connect to directory server
try:
   l = ldap.initialize("${ldpProto}://${dsHost}:${ldapsPort}")
   l.set_option(ldap.OPT_DEBUG_LEVEL, 255 )
   l.set_option(ldap.OPT_REFERRALS, 0)
   l.set_option(ldap.OPT_PROTOCOL_VERSION, 3)
   l.set_option(ldap.OPT_NETWORK_TIMEOUT, 10.0)
   l.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
   l.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
   l.simple_bind_s(binddn, pw)

except ldap.SERVER_DOWN:
   print("ERROR: LDAP server is unavailable.")
   exit(1)

except ldap.INVALID_CREDENTIALS:
   print("ERROR: The username or password is incorrect.")
   exit(49)

except ldap.LDAPError as e:
   if type(e.message) == dict and e.message.has_key('desc'):
       print(e.message['result'])
   else:
      print(e)
   exit(1)

# A dict to help build the "body" of the object
attrs = {}
attrs['cn'] = b'${dbAlias}'
attrs['objectClass'] = [b'top',b'orclDBServer',b'orclService',b'orclDBServer_92',b'orclApplicationEntity']
attrs['orclVersion'] = b'121000'
attrs['orclServiceType'] = b'DB'
attrs['orclSid'] = b'${dbSid}'
attrs['orclOracleHome'] = b'${dbHome}'
attrs['orclSystemName'] = b'${dbHost}'
attrs['orclNetDescString'] = b'${connectString}'
attrs['orclDBGlobalName'] = b'${dbAlias}'
attrs['orclNetDescName'] = b'000:cn=DESCRIPTION_0'
attrs['orclAci'] = b'access to attr=(*) by dn="${tnsAdmin}" (compare, search, read, selfwrite, write)'
attrs['orclEntryLevelAci'] = [b'access to entry by dn="${tnsAdmin}" (add)',b'access to attr=(*) by dn="${tnsAdmin}" (read, write)']

# Convert the array to LDIF
ldif = modlist.addModlist(attrs)

# Add the DB entry
try:
   l.add_s('cn=${dbAlias},cn=OracleContext,${suffix}',ldif)

except ldap.OBJECT_CLASS_VIOLATION:
   print("ERROR: Object class violation.")
   exit(65)

except ldap.ALREADY_EXISTS:
   print("already exists.")
   l.unbind_s()
   exit(1)

except ldap.INSUFFICIENT_ACCESS:
   print("insufficent access to add entry ${dbAlias}.")
   l.unbind_s()
   exit(1)

except ldap.NO_SUCH_OBJECT:
   print("naming context (${suffix}) does not exist.")
   l.unbind_s()
   exit(1)

#except ldap.LDAPError as e:
#   print(e)
#   exit(1)

except ldap.LDAPError as e:
  if type(e.message) == dict and e.message.has_key('desc'):
      print(e.message['desc'])
  else:
      print(e)
  l.unbind_s()
  exit(0)

print("success")

# Unbind before disconnecting
l.unbind_s()
exit(0)
EOPY
   pyRC=$?
   set +x
}

##############################################################################
# List registered databases
##############################################################################
list_dbs() {
   echo "List registered databases"

   dbList=$(pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(|(objectClass=orclDBServer)(objectClass=orclNetService))")
   ck4err=$(echo "${dbList}"|grep "does not exist"|sed -e "s/database entry/No database entries/g")

   if [ -n "${ck4err}" ]
   then
      echo "${ck4err}"
   else
      case ${subcmd} in
            'list') echo "${dbList}"|grep -i "^dn: "|sed -e "s/^dn: /\n/g" -e "s/cn=//gi"|cut -d',' -f1|grep -v "^$";;
          'listcs') echo "${dbList}"|egrep -i "^dn: |^orclNetDescString:"|sed -e "s/^dn: /\n/g";;
        'listldif') echo "${dbList}";;
      esac
   fi
}

##############################################################################
# Show full entry ofa specific database
##############################################################################
show_db() {
   case ${subcmd} in
      'show') echo "Show database ${dbAlias}";;
    'showcs') echo "Show connect string of database ${dbAlias}";;
   esac


   pyResult=$(pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(cn=${dbAlias})")

   ck4err=$(echo "${pyResult}"|grep "does not exist"|sed -e "s/database entry/Database entry (${dbAlias})/g")

   if [ -n "${ck4err}" ]
   then
      echo "${ck4err}"
   else
      if [ -n "${pyResult}" ]
      then
         case ${subcmd} in
            'show') echo "${pyResult}";;
          'showcs') cs=$(echo "${pyResult}"|grep -i "^orclNetDescString:"|sed -e "s/orclNetDescString: //gi")
                    echo "${dbAlias}=${cs}"|sed \
                       -e 's/[      ]//g' \
                       -e 's/[[:space:]]*#.*$//' \
                       | sed \
                       -e "s/=(DESCRIPTION=/=\n   (DESCRIPTION=/gi" \
                       -e "s/)(DESCRIPTION=/)\n   (DESCRIPTION=/gi" \
                       -e "s/)(ADDRESS_LIST=/)\n      (ADDRESS_LIST=/gi" \
                       -e "s/=(ADDRESS_LIST=/=\n      (ADDRESS_LIST=/gi" \
                       -e "s/=(SECURITY=/)=\n         (SECURITY=/gi" \
                       -e "s/)(SECURITY=/)\n         (SECURITY=/gi" \
                       -e "s/=(SSL_SERVER_DN_MATCH=/=\n            (SSL_SERVER_DN_MATCH=/gi" \
                       -e "s/)(SSL_SERVER_DN_MATCH=/)\n            (SSL_SERVER_DN_MATCH=/gi" \
                       -e "s/)(WALLET_LOCATION=/)\n            (WALLET_LOCATION=/gi" \
                       -e "s/)(TOKEN_AUTH=/)\n            (TOKEN_AUTH=/gi" \
                       -e "s/)(TENANT_ID=/)\n            (TENANT_ID=/gi" \
                       -e "s/)(AZURE_DB_APP_ID_URI=/)\n            (AZURE_DB_APP_ID_URI=/gi" \
                       -e "s/)(CLIENT_ID=/)\n            (CLIENT_ID=/gi" \
                       -e "s/(LOAD_BALANCE=/\n         (LOAD_BALANCE=/gi" \
                       -e "s/(CONNECT_TIMEOUT=/\n         (CONNECT_TIMEOUT=/gi" \
                       -e "s/(RETRY_COUNT=/\n         (RETRY_COUNT=/gi" \
                       -e "s/(RETRY_DELAY=/\n         (RETRY_DELAY=/gi" \
                       -e "s/(FAILOVER=/\n         (FAILOVER=/gi" \
                       -e "s/(TRANSPORT_CONNECT_TIMEOUT=/\n         (TRANSPORT_CONNECT_TIMEOUT=/gi" \
                       -e "s/)(ADDRESS=/)\n         (ADDRESS=/gi" \
                       -e "s/=(ADDRESS=/=\n         (ADDRESS=/gi" \
                       -e "s/=(CONNECT_DATA/=\n         (CONNECT_DATA/gi" \
                       -e "s/)(CONNECT_DATA/)\n      (CONNECT_DATA/gi" \
                       -e "s/(SERVER/\n         (SERVER/gi" \
                       -e "s/(SERVICE_NAME/\n         (SERVICE_NAME/gi"
                    ;;
         esac
      else
         echo "Database entry (${dbAlias}) or naming context (${suffix}) does not exist."
         exit
      fi
   fi
}

##############################################################################
# Export contents of the directory to a tnsnames.ora file
##############################################################################
export_to_tnsnames() {
   # Get list of databases
   readarray -t dbAliases < <(${curdir}/${cmd} list --suffix "${suffix}"|egrep -v "^Directory Server: |^User: |^List registered databases")

   # Convert the list to tnsnames.ora file
   for (( t=0; t< ${#dbAliases[*]}; t++ ))
   do
      echo -e "Exporting ${dbAliases[${t}]}...\c"
      if [ "${dbg}" == 'true' ];then set -x;fi
      ${curdir}/${cmd} showcs -n "${dbAliases[${t}]}" --suffix "${suffix}" | egrep -v "^Directory Server:|^User: |^Show conn" >> ${tnsFile}
      echo >> ${tnsFile}
      echo "done"
   done
   echo "Export to ${tnsFile} complete"
}

##############################################################################
# Export contents of the directory to a tnsnames.ora file for CMAN setup
##############################################################################
export_to_tnsnames_for_cman() {
   if [ -z "${cmanHost}" ];then echo "ERROR: Must specify --chost <host>";exit 1;fi
   
   # Get list of databases
   readarray -t dbAliases < <(${curdir}/${cmd} list --suffix "${suffix}"|egrep -v "^Directory Server: |^User: |^List registered databases")

   # Convert the list to tnsnames.ora file
   for (( t=0; t< ${#dbAliases[*]}; t++ ))
   do
      echo -e "Exporting ${dbAliases[${t}]}...\c"
      if [ "${dbg}" == 'true' ];then set -x;fi
      ${curdir}/${cmd} showcs -n "${dbAliases[${t}]}" --suffix "${suffix}" | egrep -v "^Directory Server:|^User: |^Show conn"|sed "s/\((HOST=[^)]*)\)/(\HOST=${cmanHost})/" >> ${tnsFile}
      echo >> ${tnsFile}
      echo "done"
   done
   echo "Export to ${tnsFile} complete"
}

##############################################################################
# Export contents of the directory to a tnsnames.ora file for MSIE setup
##############################################################################
export_to_tnsnames_for_msie() {
   dbProto='TCPS'
   if [ -z "${dbPort}" ];then echo "ERROR: Must provide --dbport <tcps_port>";errs='true';fi
   if [ -z "${tokenAuthMethod}" ];then echo "ERROR: Must provide --method <auth_method>";errs='true';fi
   if [ -z "${tenantID}" ];then echo "ERROR: Must provide --tenantid <msie_tenant_id>";errs='true';fi
   if [ -z "${clientID}" ];then echo "ERROR: Must provide --clientid <msie_client_id>";errs='true';fi
   if [ -z "${serveruri}" ];then echo "ERROR: Must provide --serveruri <msie_dbsvr_uri>";errs='true';fi
   if [ "${errs}" == 'true' ];then exit 1;fi

   # Get list of databases
   readarray -t dbAliases < <(${curdir}/${cmd} list --suffix "${suffix}"|egrep -v "^Directory Server: |^User: |^List registered databases")

   # Convert the list to tnsnames.ora file
   for (( t=0; t< ${#dbAliases[*]}; t++ ))
   do
      if [ "${dbg}" == 'true' ];then set -x;fi
      alias=$(echo ${dbAliases[${t}]}|cut -d'=' -f1)
      upperalias=$(echo ${alias}|tr '[:lower:]' '[:upper:]')
      cs=$(${curdir}/${cmd} showcs -n "${dbAliases[${t}]}" --suffix "${suffix}")
      ck4msie=$(echo ${cs}|grep -i "TOKEN_AUTH")
      if [ -z "${ck4msie}" ]
      then
         echo -e "Exporting ${upperalias}_${tag}...\c"
         encodeduri=$(echo ${serveruri}|sed -e "s/\//%2F/g")
         echo "${cs}" \
            | egrep -v "^Directory Server:|^User: |^Show conn" \
            | sed -e "s/^${alias}=/${upperalias}_${tag}=/" \
                  -e "s/\((PROTOCOL=[^)]*)\)/(\PROTOCOL=${dbProto})/" \
                  -e "s/\((PORT=[^)]*)\)/(\PORT=${dbPort})/" \
                  -e "s/(CONNECT_DATA=/(SECURITY=(SSL_SERVER_DN_MATCH=TRUE)(WALLET_LOCATION=SYSTEM)(TOKEN_AUTH=${tokenAuthMethod})(TENANT_ID=${tenantID})(CLIENT_ID=${clientID})(AZURE_DB_APP_ID_URI=${encodeduri}))(CONNECT_DATA=/g" \
                  -e "s/=(SECURITY=/)=\n         (SECURITY=/gi" \
                  -e "s/)(SECURITY=/)\n         (SECURITY=/gi" \
                  -e "s/ (SECURITY=/    (SECURITY=/gi" \
                  -e "s/=(SSL_SERVER_DN_MATCH=/=\n            (SSL_SERVER_DN_MATCH=/gi" \
                  -e "s/)(SSL_SERVER_DN_MATCH=/)\n            (SSL_SERVER_DN_MATCH=/gi" \
                  -e "s/)(WALLET_LOCATION=/)\n            (WALLET_LOCATION=/gi" \
                  -e "s/)(TOKEN_AUTH=/)\n            (TOKEN_AUTH=/gi" \
                  -e "s/)(TENANT_ID=/)\n            (TENANT_ID=/gi" \
                  -e "s/)(AZURE_DB_APP_ID_URI=/)\n            (AZURE_DB_APP_ID_URI=/gi" \
                  -e "s/)(CLIENT_ID=/)\n            (CLIENT_ID=/gi" \
                  -e "s/=(CONNECT_DATA/=\n         (CONNECT_DATA/gi" \
                  -e "s/)(CONNECT_DATA/)\n      (CONNECT_DATA/gi" \
                  -e "s/%2F/\//gi" \
            >> ${tnsFile}
         echo "done"
      else
         echo -e "Exporting ${dbAliases[${t}]}_${tag}...\c"
         echo "${cs}" \
            | egrep -v "^Directory Server:|^User: |^Show conn" \
            >> ${tnsFile}
         echo "done"
      fi
      echo >> ${tnsFile}
   done
   echo "Export to ${tnsFile} complete"
}

##############################################################################
# Load entries from tnsnames.ora into the directory
##############################################################################
load_tnsnames() {
   readarray -t dbAliases < <(cat ${tnsFile}|grep -v "^#.*"|sed -e "s/[ 	]//g" -e "s/(.*//g" -e "s/^)$//g" -e "s/=$//g"|grep -v "^$")

   for (( t=0; t< ${#dbAliases[*]}; t++ ))
   do
      if [ "${dbg}" == 'true' ];then set -x;fi
      dbEntry[${t}]=$(cat ${tnsFile} |sed -e "s/#.*//g" -e "s/[ 	]//g"| tr -d '[\n\r]'|sed  -e "s/^.*${dbAliases[${t}]}=/${dbAliases[${t}]}=/g" -e "s/=(DESCRIPTION/\n=(DESCRIPTION/g" -e "s/)[a-zA-Z].*$//g"|tr -d '[\n\r]')

      dbAlias=$(echo ${dbEntry[${t}]}|cut -d'=' -f1)
      connectString=$(echo ${dbEntry[${t}]}|cut -d'=' -f2-)

      pyResult=$(pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(cn=${dbAlias})" 2>&1 |grep "cn=${dbAlias}")

      if [ "${dbg}" == 'true' ];then echo -e "pyResult: ${pyResult}";fi

      if [ "${dbg}" == 'true' ];then set -x;fi
      if [ -n "${pyResult}" ]
      then
         echo "Skipping DB alias ${dbAlias} because it already exists."
      else
         echo -e "\nAdd DB alias ${dbAlias}...\c"
         #${curdir}/${cmd} register -n "${dbAlias}" -c "${connectString}" --suffix "${suffix}" 2>&1 |egrep -v "^Directory|^User:|^Register"
         ${curdir}/${cmd} register -n "${dbAlias}" -c "${connectString}" --suffix "${suffix}"
      fi

   done
   echo
}

###############################################################################
# Base variables
###############################################################################
cmd=$(basename $0)
curdir=$(dirname $0)
subcmd=$1
curdir=$(cd ${curdir}; pwd)
logdir="${curdir}/logs"
if [ -d "${logdir}" ];then true; else mkdir "${logdir}";fi
now=$(date +'%Y%m%d%H%M%S')
pylog="${logdir}/pycmd-${now}.log"
localHost=$(hostname -f 2> /dev/null|grep "\.")
localH=$(echo "${localHost}."|cut -d'.' -f 1)
errs='false'

###############################################################################
# Parse arguments
###############################################################################
while (($#)); do
    OPT=$1
    shift
    case $OPT in
        --*) case ${OPT:2} in
            help) showUsage;;
            suffix) suffix="$1";shift;;
            sid) dbSid="$1";shift;;
            base) dbBase="$1";shift;;
            home) dbHome="$1";shift;;
            subject) subjectDN="$1";shift;;
            dbhost) dbHost="$1";shift;;
            dbport) dbPort="$1";shift;;
            dbproto) dbProto="$1";shift;;
            svctype) dbServiceType="$1";shift;;
            wallet) dbWallet="$1";shift;;
            method) tokenAuthMethod="$1";shift;;
            tenantid) tenantID="$1";shift;;
            clientid) clientID="$1";shift;;
            serveruri) serveruri="$1";shift;;
            azcred) azCredential="$1";shift;;
            lb) tnsLB="(LOAD_BALANCE=on)";shift;;
            failover) tnsLB="(FAILOVER=on)";shift;;
            srcroute) tnsSourceRoute="(SOURCE_ROUTE=yes)";shift;;
            chost) cmanHost="$1";shift;;
            tag) tag="$1";shift;;
        esac;;
        -*) case ${OPT:1} in
            H) showUsage;;
            n) dbAlias="$1";shift;;
            s) dbService="$1";shift;;
            c) myConnectString="$1";shift;;
            h) dsHost="$1";shift;;
            p) ldapsPort="$1";shift;;
            D) tnsAdmin="$1";shift;;
            j) jPW="$1";shift;;
            f) tnsFile="$1";shift;;
            z) dbg="true";dbgFlag=' -z ';;
        esac;;
    esac
done

###############################################################################
# Default variable values
###############################################################################
if [ -z "${dsHost}" ];then dsHost="${localHost}";fi
if [ -z "${ldapsPort}" ];then ldapsPort='10636';fi

echo "Directory Server: ldaps://${dsHost}:${ldapsPort}"

if [ -n "${jPW}" ];then if [ -e "${jPW}" ];then bPW=$(cat ${jPW});fi;fi
if [ -z "${tnsAdmin}" ];then tnsAdmin="cn=eusadmin,ou=EUSAdmins,cn=oracleContext";fi

# Provide user context
if [ -z "${bPW}" ]
then
   if [ "${subcmd}" == 'list' ] || [ "${subcmd}" == 'listcs' ] || [ "${subcmd}" == 'listldif' ]|| [ "${subcmd}" == 'show' ] || [ "${subcmd}" == 'showcs' ] || [ "${subcmd}" == 'export' ] || [ "${subcmd}" == 'exportcman' ] || [ "${subcmd}" == 'exportmsie' ]
   then
      echo "User: Loging into directory service anonymously"
   elif [ "${subcmd}" == 'register' ] || [ "${subcmd}" == 'unregister' ]
   then
      echo "User: Loging into directory as ${tnsAdmin}"
   fi
else
   echo "User: Loging into directory as ${tnsAdmin}"
fi

if [ -z "${dbAlias}" ];then dbAlias="${localH}";fi
if [ -z "${dbService}" ];then dbService="${dbAlias}";fi

if [ -z "${suffix}" ];then echo "USAGE: Must specify --suffix <suffix>";exit 1;fi

if [ -z "${bPW}" ] && [ "${subcmd}" != 'help' ] && [ "${subcmd}" != 'list' ] && [ "${subcmd}" != 'listcs' ] && [ "${subcmd}" != 'listldif' ] && [ "${subcmd}" != 'show' ] && [ "${subcmd}" != 'showcs' ] && [ "${subcmd}" != 'export' ] && [ "${subcmd}" != 'exportcman' ] && [ "${subcmd}" != 'exportmsie' ]
then
   echo -e "Enter directory service TNS admin user's password: \c"
   while IFS= read -r -s -n1 char
   do
     [[ -z $char ]] && { printf '\n'; break; }
     if [[ $char == $'\x7f' ]]
     then
         [[ -n $bPW ]] && bPW=${bPW%?}
         printf '\b \b'
     else
       bPW+=$char
       printf '*'
     fi
   done
fi

if [ -z "${ldapPW}" ];then ldapPW="${bPW}";fi
export bPW ldapPW

if [ -z "${dbAlias}" ];then Alias="${localH}";fi
if [ -z "${dbSid}" ];then dbSid="${dbAlias}";fi

if [ -z "${dbBase}" ];then dbBase="$ORACLE_BASE";fi
if [ -z "${dbBase}" ];then dbBase="/u01/app/oracle/19c";fi

if [ -z "${dbHome}" ];then dbHome="$ORACLE_HOME";fi
if [ -z "${dbHome}" ];then dbHome="$ORACLE_BASE/dbhome_1";fi
if [ -z "${dbHome}" ];then dbHome="/u01/app/oracle/19c/dbhome_1";fi

if [ -z "${dbHost}" ];then dbHost="${localHost}";fi
if [ -z "${dbPort}" ];then dbPort="${localPort}";fi

if [ -z "${dbPort}" ];then dbPort="1521";fi
if [ -z "${dbProto}" ];then dbProto="TCP";fi

if [ -n "${subjectDN}" ];then addCertDN="(SSL_SERVER_CERT_DN=${subjectDN})";fi
if [ -z "${dbWallet}" ];then dbWallet="SYSTEM";fi

if [ -z "${tnsLB}" ];then tnsLB="(LOAD_BALANCE=off)";fi
if [ -z "${tnsFailOver}" ];then tnsFailOver="(FAILOVER=off)";fi
if [ -z "${tnsSourceRoute}" ];then tnsSourceRoute="(SOURCE_ROUTE=no)";fi

if [ -z "${dbServiceType}" ];then dbServiceType="DEDICATED";fi
case ${dbServiceType} in
   'DEDICATED') true;;
      'SHARED') true;;
      'POOLED') true;;
             *) showUsage "ERROR: Valid service types are DEDICATED, SHARED or POOLED";;
esac

if [ -n "${tenantID}" ] || [ -n "${serveruri}" ] || [ -n "${clientID}" ]
then
   if [ -z "${tenantID}" ];then showUsage "ERROR: Must provide Entra ID tenant ID";fi
   if [ -z "${serveruri}" ];then showUsage "ERROR: Must provide Entra ID database web app URL";fi
   if [ -z "${clientID}" ];then showUsage "ERROR: Must provide Entra ID client web app ID";fi

   tokenAuthMethod=$(echo ${tokenAuthMethod}|tr -s '[:upper:]' '[:lower:]')
   case ${tokenAuthMethod} in
      'interactive') tokenAuthMethod="AZURE_INTERACTIVE";;
      'passthrough') tokenAuthMethod="AZURE_DEVICE_CODE";;
          'service') tokenAuthMethod="AZURE_SERVICE_PRINCIPAL";;
                  *) showUsage "ERROR: Invalid authentication method. Valid methods: interactive, passthrough, and service"
   esac

   if [ "${tokenAuthMethod}" == 'AZURE_SERVICE_PRINCIPAL' ]
   then
      if [ -z "${azCredential}" ];then showUsage "ERROR: Must provide Entra ID credential file";fi
   fi

   if [ -z "${connectString}" ]
   then
      if [ -n "${tenantID}" ] || [ -n "${serveruri}" ] || [ -n "${clientID}" ]
      then
         if [ -n "${azCredential}" ]
         then
            connectString="(DESCRIPTION=(ADDRESS=(PROTOCOL=${dbProto})(HOST=${dbHost})(PORT=${dbPort}))(SECURITY=(SSL_SERVER_DN_MATCH=TRUE)${addCertDN}(WALLET_LOCATION=${dbWallet})(TOKEN_AUTH=${tokenAuthMethod})(TENANT_ID=${tenantID})(AZURE_DB_APP_ID_URI=${serveruri})(CLIENT_ID=${clientID})(AZURE_CREDENTIALS=${azCredential}))(CONNECT_DATA=(SERVER=${dbServiceType})(SERVICE_NAME=${dbService})))"
         else
            connectString="(DESCRIPTION=(ADDRESS=(PROTOCOL=${dbProto})(HOST=${dbHost})(PORT=${dbPort}))(SECURITY=(SSL_SERVER_DN_MATCH=TRUE)${addCertDN}(WALLET_LOCATION=${dbWallet})(TOKEN_AUTH=${tokenAuthMethod})(TENANT_ID=${tenantID})(AZURE_DB_APP_ID_URI=${serveruri})(CLIENT_ID=${clientID}))(CONNECT_DATA=(SERVER=${dbServiceType})(SERVICE_NAME=${dbService})))"
         fi
      else
         connectString="(DESCRIPTION=(ADDRESS=(PROTOCOL=${dbProto})(HOST=${dbHost})(PORT=${dbPort}))(CONNECT_DATA=(SERVER=${dbServiceType})(SERVICE_NAME=${dbService})))"
      fi
   fi
else
   connectString="(DESCRIPTION=(ADDRESS=(PROTOCOL=${dbProto})(HOST=${dbHost})(PORT=${dbPort}))(CONNECT_DATA=(SERVER=${dbServiceType})(SERVICE_NAME=${dbService})))"
fi

if [ -z "${tnsFile}" ];then tnsFile="${curdir}/tnsnames.ora";fi

if [ -n "${myConnectString}" ];then connectString="${myConnectString}";fi
if [ -z "${tag}" ];then tag="MSIE";fi
tag=$(echo ${tag}|tr '[:lower:]' '[:upper:]')

###############################################################################
# Process subcommand
###############################################################################
if [ "${dbg}" == 'true' ];then set -x;fi
case ${subcmd} in
       'register') register_db;;
     'unregister') unregister_db;;
           'list') list_dbs;;
         'listcs') list_dbs;;
       'listldif') list_dbs;;
           'show') show_db;;
         'showcs') show_db;;
         'export') export_to_tnsnames;;
     'exportcman') export_to_tnsnames_for_cman;;
     'exportmsie') export_to_tnsnames_for_msie;;
           'load') load_tnsnames;;
                *) showUsage;;
esac
set +x
