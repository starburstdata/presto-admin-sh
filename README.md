# presto-admin-sh

Happy path steps:
1. ./presto-admin.sh init cluster_name
2. ./presto-admin.sh rpm_deploy cluster_name rpm_path.rpm
3. ./presto-admin.sh install cluster_name
4. vim ~/.presto-admin-sh/cluster_name/configuration/coordinator/config.properties
5. vim ~/.presto-admin-sh/cluster_name/configuration/catalog/hive.properties
6. ./presto-admin.sh config_deploy cluster_name
7. ./presto-admin.sh start cluster_name
8. ./presto-admin.sh stop cluster_name
9. ./presto-admin.sh uninstall cluster_name
