# presto-admin-sh

Simple bash alternative to [presto-admin](https://github.com/prestodb/presto-admin).
When python causes more harm than good, you have an option to fallback to plain bash.

1. Download and installation:

```
wget https://raw.githubusercontent.com/starburstdata/presto-admin-sh/master/presto-admin.sh
chmod +x  presto-admin.sh
```

2. Create configuration of your cluster. Script will ask your for:
 - SSH private key that will be used to access all cluster nodes.
 - user name for SSH connection (in case user is not a root, some operation performed on cluster will require sudo).
 - Coordinator worker node ip
 - Worker nodes ips (separated by space)

```
./presto-admin.sh init cluster_name
```

3. Deploy a `presto-server-rpm-${presto_version}.rpm` to all nodes.
In case your connection to cluster is slow, you might want to do it manually, then please upload rpm file to `/tmp/presto.rpm` on all nodes.

```
./presto-admin.sh rpm_deploy cluster_name rpm_path.rpm
```

4. Install `presto-server-rpm-${presto-version}.rpm` on all nodes.

```
./presto-admin.sh install cluster_name
```

5. Now you can update your Presto configuration.
 - coordinator configuration is stored under: `~/.presto-admin-sh/cluster_name/configuration/coordinator/config.properties`
 - worker configuration is stored under: `~/.presto-admin-sh/cluster_name/configuration/worker/config.properties`
 - catalog configuration is stored under: `~/.presto-admin-sh/cluster_name/configuration/catalog/jmx.properties`
After initial cluster configuration, mentioned above directories contain a minimal list of configuration files, please add more files if needed. Below you will find example commands:

```
vim ~/.presto-admin-sh/cluster_name/configuration/coordinator/config.properties
vim ~/.presto-admin-sh/cluster_name/configuration/worker/config.properties
vim ~/.presto-admin-sh/cluster_name/configuration/catalog/hive.properties
```

6. Deploy configuration to all nodes.

```
./presto-admin.sh config_deploy cluster_name
```

7. Start Presto cluster.

```
./presto-admin.sh start cluster_name
```

8. Stop Presto cluster.

```
./presto-admin.sh stop cluster_name
```

9. Uninstall `presto-server-rpm-${presto-version}.rpm` on all nodes.

```
./presto-admin.sh uninstall cluster_name
```
