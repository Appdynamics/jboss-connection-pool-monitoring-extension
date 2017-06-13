# jboss-connection-pool-monitoring-extension #

An AppDynamics extension to be used with a stand alone Java machine agent to provide JBoss DataSource connection pool statistics.

## Use Case ##

Red Hat JBoss Application Server and/or Enterprise Application Platform (EAP) are platforms to develop and deploy Java EE applications.

As of JBoss EAP 6 (and JBoss Application Server 7) the MBEAN jboss.jca.ManagedConnectionPool is no longer available and this prevents access to DataSource connection statistics via JMX. 

This monitoring extension makes use of commands via **jboss-cli.sh** instead.

### Metrics Provided ###

The following table contains a list of the JBoss EAP 6 core datasource statistics:

Name                | Description
--------------------|---------------------------------
ActiveCount         |The number of active connections. Each of the connections is either in use by an application or available in the pool
AvailableCount      |The number of available connections in the pool.
AverageBlockingTime |The average time spent blocking on obtaining an exclusive lock on the pool. The value is in milliseconds.
AverageCreationTime |The average time spent creating a connection. The value is in milliseconds.
CreatedCount        |The number of connections created.
DestroyedCount      |The number of connections destroyed.
InUseCount          |The number of connections currently in use.
MaxCreationTime     |The maximum time it took to create a connection. The value is in milliseconds.
MaxUsedCount        |The maximum number of connections used.
MaxWaitCount        |The maximum number of requests waiting for a connection at the same time.
MaxWaitTime         |The maximum time spent waiting for an exclusive lock on the pool.
TimedOut            |The number of timed out connections.
TotalBlockingTime   |The total time spent waiting for an exclusive lock on the pool. The value is in milliseconds.
TotalCreationTime   |The total time spent creating connections. The value is in milliseconds.
WaitCount           |The number of requests that had to wait for a connection.

## Prerequisites ##

Starting from EAP 6.3, DataSource statistics need to be explicitly enabled before accessing as they are disabled by default to avoid any performance impact. 

Execute in **jboss-cli.sh** command:
```
/subsystem=datasources/data-source=ExampleDS:write-attribute(name=statistics-enabled,value=true)
```

Alternatively set the statistics-enabled attribute to true in the **standalone.xml** or **domain.xml** respectively.
```
<datasource jndi-name="java:jboss/datasources/ExampleDS" pool-name="ExampleDS" enabled="true" use-java-context="true" statistics-enabled="true">
```

A restart of the JBoss server is required to take effect. To know more, please follow this [link](https://access.redhat.com/solutions/268793#EAP63) (Red Hat account required)

## Installation ##

1. After downloading and unzipping, use an editor to configure the user defined variables in **JBossDatasourceMonitor/data-sources.sh** according the provided comments.
2. Verify your settings by running **data-sources.sh** from the command prompt and with the user permissions of the Machine Agent. The output should look like:

    ```
    name=Custom Metrics|JBoss|data-source|ExampleDS|ActiveCount,aggregator=OBSERVATION,value=10
    name=Custom Metrics|JBoss|data-source|ExampleDS|AvailableCount,aggregator=OBSERVATION,value=20
    ...
    ```
3. Copy directory **JBossDatasourceMonitor** into directory **MACHINE_AGENT_HOME/monitors**
4. Restart the machine agent, check its logs and any non empty **jboss_data-sources_$$.err** file in the **JBossDatasourceMonitor** directory. 
5. Finally lookup the provided metrics via the AppDynamics metrics browser under:

    ```
   Application Infrastructure Performance> Root> Custom Metrics> JBoss> data-sources> DataSourceName
    ````

## Troubleshooting steps ##
Use the following suggestions to troubleshoot any issues.

-  Check the machine agent log files for any issues. When seeing in the machine-agent.log **WARN** messages like below, you need to set and export **JAVA_HOME** in the --- User defined variables --- section of data-sources.sh (e.g. export JAVA_HOME=/opt/java/jdk1.7.0_79).
```
[Worker-6] 06 Jun 2017 15:04:50,781  WARN MonitorTaskRunner$1 - ignoring error line:[/opt/jboss-6.3/bin/jboss-cli.sh: line 70: java: command not found]
```
- Check any non empty **jboss_data-sources_$$.err** file in the **JBossDatasourceMonitor** directory.
- Start **jboss-cli.sh** from the command line using the credentials of the machine agent and execute commands **"connect"** and **"/subsystem=datasources:read-resource"** similar to the following example:

   ```
   /opt/jboss-eap-6.3/bin/jboss-cli.sh
   You are disconnected at the moment. Type 'connect' to connect to the server or 'help' for the list of supported commands.
   [disconnected /] connect [JBOSS_HOST:JBOSS_PORT]
   [standalone@localhost:9999 /] /subsystem=datasources:read-resource
   {
       "outcome" => "success",
       "result" => {
           "data-source" => {"ExampleDS" => undefined},
           "jdbc-driver" => {"h2" => undefined},
           "xa-data-source" => undefined
       },
      "response-headers" => {"process-state" => "reload-required"}
   }
   [standalone@localhost:9999 /] exit
   ```
- Adjust the script to print debug information

#### Notes: ####
- In JBoss domain mode **jboss-cli.sh** commands require command pre-pending with **/host=\<hostName>/server=\<serverName>/**
For example:

    ```
    /host=slave/server=server-one/subsystem=datasources/datasource=ExampleDS:read-resource(include-runtime=true)
    ```
- By default, a Machine agent or a AppServer agent can only send a fixed number of metrics to the controller. To change this limit, please follow the instructions mentioned [here](http://docs.appdynamics.com/display/PRO14S/Metrics+Limits). For example:

    ```
    java -Dappdynamics.agent.maxMetrics=2500 -jar machineagent.jar
    ```

## Contributing ##

Always feel free to fork and contribute any changes directly via [GitHub][].

## Community ##

Find out more in the [AppDynamics Exchange][].

## Support ##

For any questions or feature request, please contact [AppDynamics Center of Excellence][].

**Version:** 1.0.4
**Controller Compatibility:** 4.1+
**JBoss EAP Versions Tested On:** 6 and 7

[Github]: https://github.com/Appdynamics/jboss-connection-pool-monitoring-extension
[AppDynamics Exchange]: http://community.appdynamics.com/t5/AppDynamics-eXchange/idb-p/extensions
[AppDynamics Center of Excellence]: mailto:ace-request@appdynamics.com
