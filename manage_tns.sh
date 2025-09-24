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
     ${cmd} [subcommand] -n <alias> [options]

DESCRIPTION
     The purpose of this script is to simplify TNS entry management in a
     LDAP-based directory service

     Subcommands:
        register      Register a database

        unregister    Unregister a database

        show          Show the database TNS entry

        list          List all registered database

SYNOPSIS

     Register database with default connect string
        ${cmd} register -n <alias>

     Register database with custom connect string
        ${cmd} register -n <alias> -c "<string>"

     Register database with Entra ID integration
        ${cmd} register -n <alias> --method interactive --tenantid <id> --clientid <id> --serveruri <uri>

     Unregister database
        ${cmd} unregister -n <alias>

     Show database entry
        ${cmd} show -n <alias>

     List database entries
        ${cmd} list

OPTIONS
     The following options are supported:

     -z                 Show debug output

     -n <alias>         Database alias name
                        Default: ${localH}

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

/usr/bin/${pycmd} - 2>> ${pylog} <<EOPY
import sys,ldap,ldif

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
  print("LDAP server is unavailable.")
  exit(1)

except ldap.INVALID_CREDENTIALS:
  print("Your username or password is incorrect.")
  exit(1)

except ldap.LDAPError as e:
  if type(e.message) == dict and e.message.has_key('desc'):
      print(e.message['desc'])
  else:
      print(e)
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

except ldap.LDAPError as e:
    print(e)

l.unbind_s()
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

   echo -e "Unregister database ${dbAlias}"

   regdb_log="${logdir}/regdb-${now}.log"
   touch "${regdb_log}"
   chmod 0600 "${regdb_log}"

   getPyCmd
   ${pycmd} - >> ${regdb_log} 2>&1 <<EOPY
import sys,ldap,ldif, ldap.modlist as modlist

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
  print("LDAP server is unavailable.")
  exit(1)

except ldap.INVALID_CREDENTIALS:
  print("Your username or password is incorrect.")
  exit(1)

except ldap.LDAPError as e:
  if type(e.message) == dict and e.message.has_key('desc'):
      print(e.message['desc'])
      exit(1)
  else:
      print(e)
  exit(0)

# Delete the DB entry
l.delete_s('cn=${dbAlias},cn=OracleContext,${suffix}')

# Unbind before disconnecting
l.unbind_s()
EOPY
   pyRC=$?
   case ${pyRC} in
         0) echo "Database unregistration completed successfully";;
         *) echo "ERROR: Database unregistration failed";;
   esac
   set +x
}

##############################################################################
# Register DB
##############################################################################
register_db() {
   checkPyLdap
   ldpProto='ldaps'
   if [ "${dbg}" == 'true' ];then set -x;fi

   echo -e "Register database ${dbAlias}"

   regdb_log="${logdir}/regdb-${now}.log"
   touch "${regdb_log}"
   chmod 0600 "${regdb_log}"

   getPyCmd
   ${pycmd} - >> ${regdb_log} 2>&1 <<EOPY
import sys,ldap,ldif, ldap.modlist as modlist

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
  print("LDAP server is unavailable.")
  exit(1)

except ldap.INVALID_CREDENTIALS:
  print("Your username or password is incorrect.")
  exit(1)

except ldap.LDAPError as e:
  if type(e.message) == dict and e.message.has_key('desc'):
      print(e.message['desc'])
      exit(1)
  else:
      print(e)
  exit(0)

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

# Other attributes that normally exist but I don't know what the values are
#attrs['oracleAci'] = b'access to entry by dn="${tnsAdmin}" (browse, add, delete)',
#userPassword: {MR-SHA512}cXxZ+OSnT5GhV96zxMxGEi8vS9xNFOZG2MhlXbDPJZq6DytQZEL0JPVKZFqZ4OmvMm7/j6rMZ2qqM1LBeFp/+ZfFybx+VZN+x4vnErgBz5A=
#userPassword: {SSHA}EiE7dhOtUOG5Q0ccpMUKiogJjJp0/BcxdSObVw==
#orclcommonrpwdattribute: {SASL-MD5}jWZfBnyIzPfXwhhyjRyr7w==

# Convert the array to LDIF
ldif = modlist.addModlist(attrs)

# Add the DB entry
l.add_s('cn=${dbAlias},cn=OracleContext,${suffix}',ldif)

# Unbind before disconnecting
l.unbind_s()
EOPY
   pyRC=$?
   case ${pyRC} in
         0) echo "Database registration completed successfully";;
         *) echo "ERROR: Database registration failed";;
   esac
   set +x
}

##############################################################################
# List registered databases
##############################################################################
list_dbs() {
   echo "List registered databases"

   if [ "${dbg}" == 'true' ]
   then
      pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(|(objectClass=orclDBServer)(objectClass=orclNetService))"
   else
      pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(|(objectClass=orclDBServer)(objectClass=orclNetService))"|egrep -i "^dn: |^orclNetDescString:"|sed -e "s/^dn: /\n/g"
   fi
}

##############################################################################
# Show full entry ofa specific database
##############################################################################
show_db() {
   echo "Show database ${dbAlias}"

   pyResult=$(pyLdapSearch ldaps "${dsHost}" "${ldapsPort}" "${tnsAdmin}" "${suffix}" 'sub' "(cn=${dbAlias})")

   if [ -n "${pyResult}" ]
   then
      echo "${pyResult}"
   else
      echo "Database ${dbAlias} is not registered"
   fi
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
if [ -z "${ldapPW}" ];then ldapPW="${bPW}";fi

# Provide user context
if [ -z "${bPW}" ]
then
   if [ "${subcmd}" == 'list' ] || [ "${subcmd}" == 'show' ]
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

if [ -z "${suffix}" ];then suffix="dc=example,dc=com";fi

if [ -z "${bPW}" ] && [ "${subcmd}" != 'help' ] && [ "${subcmd}" != 'list' ] && [ "${subcmd}" != 'show' ]
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

if [ -n "${myConnectString}" ];then connectString="${myConnectString}";fi

###############################################################################
# Process subcommand
###############################################################################
if [ "${dbg}" == 'true' ];then set -x;fi
case ${subcmd} in
       'register') register_db;;
     'unregister') unregister_db;;
           'list') list_dbs;;
           'show') show_db;;
                *) showUsage;;
esac
set +x
