#检查是否新项目
project_mount_dir="/{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/"
if [ ! -d "$project_mount_dir" ]; then
    mkdir -p /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/resource
    mkdir -p /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/{web,app}/logs
    mkdir -p /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/{web,app}/config
    #创建资源文件
    cp -r /{{prefix_dir}}/config/resource/* /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/resource/
    #创建配置文件
    cp /{{prefix_dir}}/config/web/* /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/web/config
    cp /{{prefix_dir}}/config/app/* /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/app/config
    sed -i "s#{{log_path}}#/{{prefix_dir}}/{{service_dir}}/web/logs#g" /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/web/config/log4j2.xml
    sed -i "s#{{log_path}}#/{{prefix_dir}}/{{service_dir}}/app/logs#g" /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/app/config/log4j2.xml
    #创建数据库
    rpm -ivh --nodeps /{{prefix_dir}}/*.rpm
    /usr/bin/mysql -h {{db_host}} -P {{db_port}} -u root -p{{db_root_password}} -s -e "CREATE DATABASE qa_{{project_type}}_{{project_name}} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;CREATE USER 'qa_{{project_type}}_{{project_name}}'@'%' IDENTIFIED BY 'qa_{{project_type}}_{{project_name}}';grant all privileges on qa_{{project_type}}_{{project_name}}.* to 'qa_{{project_type}}_{{project_name}}'@'%';flush privileges;"
fi
# 创建挂载软连接
ln -s /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/resource /{{prefix_dir}}/{{service_dir}}/resource
ln -s /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/{{service_type}}/logs /{{prefix_dir}}/{{service_dir}}/{{service_type}}/logs
ln -s /{{prefix_dir}}/nfs/{{project_type}}/{{resource_name}}/{{service_type}}/config /{{prefix_dir}}/{{service_dir}}/{{service_type}}/config
# 修改应用ip为本机
app_proper_files=$(cd /{{prefix_dir}}/{{service_dir}}/{{service_type}}/config/ && ls application.properties 2>/dev/null | wc -l)
if [ "$app_proper_files" != "0" ]; then
    export docker_ip=$(tail -n 1 /etc/hosts | awk '{print $1}')
    sed -r -i "s/(AppDeployIp=).*/\1$docker_ip/" /{{prefix_dir}}/{{service_dir}}/{{service_type}}/config/application.properties
fi
# 替换license
cd /{{prefix_dir}}/{{service_dir}}/{{service_type}}/
jar -uvf0 *.jar BOOT-INF
# 启动
java -Xdebug -Xrunjdwp:transport=dt_socket,address={{debug_port}},server=y,suspend=n -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/{{prefix_dir}}/{{service_dir}}/{{service_type}}/logs -Djava.security.egd=file:/dev/urandom -Xbootclasspath/a:/{{prefix_dir}}/{{service_dir}}/{{service_type}}/config -Xms{{jvm_Xms}} -Xmx{{jvm_Xmx}} -jar /{{prefix_dir}}/{{service_dir}}/{{service_type}}/*.jar
