#!/bin/sh

#
#          Name: data-sources.sh
#   Description: AppDynamics Machine extension to report JBoss data-source statistics
#        Author: Bart van Knijff - AppDynamics
#
#  Version  Date          Who  Comment
#  -------  -----------   ---  ------------------------------------------------------
#     1.00  14 Jul 2016   BvK  Initial version
#     1.01  21 Jul 2016   BvK  Update for EAP 7 and new style jboss-cli.sh output
#     1.02  28 Jul 2016   BvK  Automated data-source discovery. Tested against JBoss EAP 6 & 7
#     1.03   4 Aug 2016   BvK  Streamlined options. Better error reporting and bug fixes
#     1.04   8 Aug 2016   BvK  Added DOMAIN option.
#     1.05  17 Apr 2017   BvK  Optimized cpu usage when processing many datasources
#
# General notes:
# 1. After setting the user defined variables, verify your settings by running this script from the command prompt
#    The output should look like:
#      name=Custom Metrics|JBoss|data-source|ExampleDS|ActiveCount,aggregator=OBSERVATION,value=10
#      name=Custom Metrics|JBoss|data-source|ExampleDS|AvailableCount,aggregator=OBSERVATION,value=20
#      ...
#

# --- User defined variables --------------------------------------------------------
#
#JBOSS_HOME=/opt/jboss-eap-6.2
JBOSS_HOME=/opt/jboss-eap-6.3
#JBOSS_HOME=/opt/jboss-eap-6.4
#JBOSS_HOME=/opt/jboss-eap-7.0
#
# Use one the following JBOSS_CLI settings depending whether running as the JBoss owner account (e.g. jboss)
JBOSS_CLI="$JBOSS_HOME/bin/jboss-cli.sh"
# The next JBOSS_CLI definition could be required when the Machine Agent runs with root permissions
#JBOSS_CLI="su - jboss -c $JBOSS_HOME/bin/jboss-cli.sh"
# Use the following JBOSS_CLI when requiring a JBoss Management username and password
#JBOSS_CLI="$JBOSS_HOME/bin/jboss-cli.sh --user=<username> --password=<password>"
#
# Check on which IP-Address and Port JBoss is listening via: netstat -na | grep PORT|LISTEN
# This should be in line with the definitions in standalone.xml or host.xml when running in domain mode
JBOSS_HOST=localhost
#
# --- JBoss port settings ---
# The ports my differ please see your $JBOSS_HOME/domain/configuration/host.xml (default) or
# $JBOSS_HOME/standalone/configuration/standalone.xml to see which ports you have exposed
#
# Check the section that says: native-interface security-realm="ManagementRealm"
#   <management-interfaces>
#       <native-interface security-realm="ManagementRealm">
#           <socket interface="management" port="${jboss.management.native.port:9999}"/>
#       </native-interface>
#       <http-interface security-realm="ManagementRealm">
#           <socket interface="management" port="${jboss.management.http.port:9990}"/>
#       </http-interface>
#  </management-interfaces>
#
JBOSS_PORT=9999  # default port for listing data-sources on jboss-eap-6.x
#JBOSS_PORT=9990  # default port for listing data-sources on jboss-eap-7.x
#
# -- Data source settings --
# The script will auto detect all available data-sources when DATA_SOURCES=""
# When you only want to monitor specific data-sources, set it to a single or list of value(s)
# e.g. DATA_SOURCES="ExampleDS" or DATA_SOURCES="ExampleDS OracleDS PostgreSQL"
#
DATA_SOURCES=""
#
# -- JBoss standalone mode --
# In JBoss standalone mode use DOMAIN=""
DOMAIN=""
#
# -- JBoss domain mode --
# In JBoss domain mode use DOMAIN="/host=hostName/server=serverName"
# In domain mode jboss-cli.sh commands require command pre-pending with /host=<hostName>/server=<serverName>/
#   e.g. /host=slave/server=server-one/subsystem=datasources/datasource=ExampleDS:read-resource(include-runtime=true)
#   Run a single copy of this script for each hostName/serverName combination you want to monitor data-source usage
#DOMAIN="/host=hostName/server=serverName"
#
# --- End of User defined variables ---------------------------------------------------

CMD_FILE=jboss_data-sources_$$.cmd
TMP_FILE=jboss_data-sources_$$.tmp
ERR_FILE=jboss_data-sources_$$.err

case `uname` in
Darwin|Linux)
  AWK=awk
  ;;
*)
  AWK=nawk
  ;;
esac

if [ -z "$DATA_SOURCES" ]; then
  AUTO_DISCOVERY=1
else
  AUTO_DISCOVERY=0
fi

while true; do

  if [ "$DATA_SOURCES" = "" ]; then
    # When JBoss is stopped for longer than 60 seconds this if-branche will be executed, because the next JBOSS_CLI will error exit
    # This will likely happen when data-sources are added manually, but not 100% guaranteed. Restart the Machine Agent instead.

    # echo "Discover JBoss data-sources"
    echo "connect $JBOSS_HOST:$JBOSS_PORT
$DOMAIN/subsystem=datasources:read-resource" | $JBOSS_CLI | $AWK -F '[ ,"{}]+' -v OFS='' '/=>/ { if (ds > 0) print $2 }
/[ "]data-source/ { ds = 1; if (length($4)) print $4 }
/},$/ { ds = 0 }' > $TMP_FILE 2>> $ERR_FILE
    DATA_SOURCES=`cat $TMP_FILE`
  fi

  echo "connect $JBOSS_HOST:$JBOSS_PORT" > $TMP_FILE

  for ds in $DATA_SOURCES; do
    echo "$DOMAIN/subsystem=datasources/data-source=${ds}/statistics=pool:read-resource(include-runtime=true)" >> $TMP_FILE
  done

  if [ -n "$DATA_SOURCES" ]; then

    mv $TMP_FILE $CMD_FILE
    cat $CMD_FILE | $JBOSS_CLI > $TMP_FILE 2>> $ERR_FILE
    ERR=$?

    if [ $ERR -ne 0 ]; then
      echo "$JBOSS_CLI exited with error $ERR" >> $ERR_FILE

      if [ $AUTO_DISCOVERY -gt 0 ]; then
        DATA_SOURCES=""
      fi

    fi

    if [ $ERR -eq 0 -a -s $TMP_FILE ]; then

      cat $TMP_FILE | $AWK -F '[ ,"{}]+' -v OFS='' '
function printIt (_m, _v) {
  if (length(_m) && match(_v, "^[0-9]+$"))
    print "name=Custom Metrics|JBoss|data-sources|" D "|" _m ",aggregator=OBSERVATION,value=" _v
}

/data-source=/ { sub(".*data-source=", "", $3); sub("/statistics=.*", "", $3); D = $3 }
/=>/ {gsub("L$", "", $4); printIt($2, $4)}' 2>> $ERR_FILE

      ERR=$?

      if [ $ERR -ne 0 ]; then
        echo "$AWK exited with error $ERR" >> $ERR_FILE
      fi
    fi

  fi

  #mv $TMP_FILE tmp.txt
  rm -f $TMP_FILE $CMD_FILE
  if [ ! -s $ERR_FILE ]; then
    rm -f $ERR_FILE
  fi

  sleep 60
done
