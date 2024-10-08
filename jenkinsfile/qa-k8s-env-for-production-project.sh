#! /bin/bash
#git_base
mod_git_base="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/"
#数据库文件
project_database="$mod_git_base/database/qa-k8s-env-for-production-project-database.csv"
#构建目录
project_jenkins_work_path="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/workspace/"
mod_chart_prefix_path="/home/k8s/chart/124-qa/"
mod_docker_image_prefix_path="/home/k8s/build/project_image/"
mod_docker_image_path="$mod_docker_image_prefix_path/qa-k8s-env-for-production-project-mod-server/"
# jdk存放路径
jdk_path="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/jdk/"
mysql_path="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/mysql/"
# 中间件连接信息
declare -A property
#database
property['db_host']="172.18.1.100"
property['db_port']="3306"
property['db_root_password']="123456"
#redis
property['redis_host']="172.18.1.190"
property['redis_port']="31873"
property['redis_password']="test"
#minio
property['minio_api_url']="http://172.18.1.190:31874"
property['minio_accessKey']="admin"
property['minio_secretKey']="root123456"
#nacos
property['nacos_url']="http://172.18.9.190:31876"
property['nacos_username']="dahantc"
property['nacos_password']="dahantc"
#jvm
property['jvm_Xms']="512m"
property['jvm_Xmx']="3072m"

function error_exit() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" 1>&2
    exit 1
}

function printf_std() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" 1>&2
}

#数据库相关
function db_add_project() {
    printf_std "obligate"
}

function db_query_project_type_all() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') 查询project_type_all" >>$mod_git_base/jenkinsfile/log.log
    #拉取最新构建mod
    mkdir -p $mod_git_base
    cd $mod_git_base
    git init >/dev/null 2>&1
    git pull http://gitlab.dahantc.com/8574/qa-k8s-env-for-production-project.git >/dev/null 2>&1
    # #恢复git本地仓库误删文件
    # git ls-files -d | xargs echo -e | xargs git checkout --
    # #清除git本地仓库新增文件
    # git checkout . && git clean -xdf
    local col_name="project_name"
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    echo $(awk -v FS="," 'NR>1{print $'"$col_num"'}' $project_database | cut -d '-' -f1 | sort -u | xargs | sed 's/[ ][ ]*/,/g' | sed 's/$/,/') #结尾添加分隔符解决jenkins插件active choice返回列表的最后一项无法传递参数的bug
}

function db_query_stripped_project_name_in_project_type() {
    local project_type=${1:-1}
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') 查询stripped_project_name：$project_type" >>$mod_git_base/jenkinsfile/log.log
    local col_name="project_name"
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    echo $(awk -v FS="," -v col_num=$col_num 'NR>1{print $col_num}' $project_database | grep $project_type | cut -d '-' -f2 | sort -u | xargs | sed 's/[ ][ ]*/,/g' | sed 's/$/,/')
}

function db_query_service_type_in_project() {
    local project_type=${1:-1}
    local project_name=${2:-1}
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') 查询service_type：$project_type,$project_name" >>$mod_git_base/jenkinsfile/log.log
    local col_name="project_name"
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    echo $(awk -v FS="," -v col_num=$col_num 'NR>1{print $col_num}' $project_database | grep $project_name | grep $project_type | cut -d '-' -f3 | sort -u | xargs | sed 's/[ ][ ]*/,/g' | sed 's/$/,/')
}

function db_query_property() {
    local col_name=${1:-1}
    local project_name=${2:-1}
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') 查询property：$col_name,$project_name" >>$mod_git_base/jenkinsfile/log.log
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    if [[ $col_num == "" ]]; then
        error_exit "bad query variable:\ncol_name:$col_name\nproject_name:$project_name"
    else
        echo $(grep $project_name $project_database | grep -v plugin | cut -d ',' -f$col_num | head -n 1)
    fi
}

#获取git分支
function git_branch() {
    local project_name=${1:-1}
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') 查询git_branch：$project_name" >>$mod_git_base/jenkinsfile/log.log
    local token=$(echo $(cat /var/jenkins_home/workspace/jenkins/get_project_branch.sh.bak | grep -E 'token=' | awk -F "=" 'NR==1{print $2}' | sed 's/"//g'))
    local gitlab_url="gitlab.dahantc.com"
    local project_id=$(db_query_property "git_id" $project_name)
    local total_git_branch_list="master"
    # printf_std "查询${project_name}的git分支，git_id为${project_id}"
    for i in $(seq 1 20); do
        local branch_list=$(curl -s --header "PRIVATE-TOKEN: ${token}" "http://gitlab.dahantc.com/api/v4/projects/${project_id}/repository/branches?per_page=200&page=$i" | jq -r ".[].name" | grep -Ev "master" | tr "\n" "," | sed 's/,$//g')
        if [[ $branch_list != "" ]]; then
            total_git_branch_list+=",$branch_list"
        fi
    done
    echo $total_git_branch_list
}

#初始化构建
function init_build() {
    #拉取最新构建mod
    printf_std "拉取最新构建mod"
    mkdir -p $mod_git_base
    cd $mod_git_base
    git init
    git pull http://gitlab.dahantc.com/8574/qa-k8s-env-for-production-project.git
    #恢复git本地仓库误删文件
    printf_std "恢复git本地仓库误删文件"
    git ls-files -d | xargs echo -e | xargs git checkout --
    #清除git本地仓库新增文件
    printf_std "清除git本地仓库新增文件"
    git checkout . && git clean -xdf
    #初始化构建目录
    printf_std "初始化构建目录"
    #mod_helm_chart
    printf_std "对比mod_helm_chart的md5"
    server_mod_chart_md5_it_git=$(echo $(cd $mod_git_base/mod_chart/qa124-project-ema80-mod-server/ && find . -type f -exec md5sum {} + | md5sum | cut -d" " -f1))
    server_mod_chart_md5=$(echo $(cd $mod_chart_prefix_path/qa124-project-ema80-mod-server/ && find . -type f -exec md5sum {} + | md5sum | cut -d" " -f1))
    if [[ $server_mod_chart_md5_it_git != $server_mod_chart_md5 ]]; then
        printf_std "更新qa124-project-ema80-mod-server"
        rm -rf $mod_chart_prefix_path/qa124-project-ema80-mod-server
        cp -r $mod_git_base/mod_chart/qa124-project-ema80-mod-server $mod_chart_prefix_path
    fi
    vue_mod_chart_md5_it_git=$(echo $(cd $mod_git_base/mod_chart/qa124-project-ema80-mod-vue/ && find . -type f -exec md5sum {} + | md5sum | cut -d" " -f1))
    vue_mod_chart_md5=$(echo $(cd $mod_chart_prefix_path/qa124-project-ema80-mod-vue/ && find . -type f -exec md5sum {} + | md5sum | cut -d" " -f1))
    if [[ $vue_mod_chart_md5_it_git != $vue_mod_chart_md5 ]]; then
        printf_std "更新qa124-project-ema80-mod-vue"
        rm -rf $mod_chart_prefix_path/qa124-project-ema80-mod-vue
        cp -r $mod_git_base/mod_chart/qa124-project-ema80-mod-vue $mod_chart_prefix_path
    fi
    # 清除上次构建镜像
    printf_std "清除上次构建镜像"
    mkdir -p $mod_docker_image_path
    rm -rf $mod_docker_image_path
    # 准备镜像构建目录
    printf_std "准备镜像构建目录"
    cp -r $mod_git_base/mod_docker_image/qa-k8s-env-for-production-project-mod-server/ $mod_docker_image_prefix_path
    mkdir -p $mod_docker_image_path/config/
    # 准备jdk安装包
    mkdir -p $jdk_path
    jdk_file="$jdk_path/jdk-8u191-linux-x64.tar.gz"
    if [ -f "$jdk_file" ]; then
        printf_std "jdk文件已存在: $jdk_file"
    else
        printf_std "jdk文件不存在: $jdk_file，下载文件"
        wget https://mirrors.huaweicloud.com/java/jdk/8u191-b12/jdk-8u191-linux-x64.tar.gz -P $jdk_path
    fi
    cp -r $jdk_file $mod_docker_image_path/
    # 准备mysql_client安装包
    mkdir -p $mysql_path
    mysql_file="$mysql_path/mysql-community-client-8.0.29-1.el7.x86_64.rpm"
    if [ -f "$mysql_file" ]; then
        printf_std "mysql_client文件已存在: $mysql_file"
    else
        printf_std "mysql_client文件不存在: $mysql_file，下载文件"
        wget https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-8.0/mysql-community-client-8.0.29-1.el7.x86_64.rpm -P $mysql_path
    fi
    cp -r $mysql_file $mod_docker_image_path/
}

#准备镜像
function prepare_for_docker_image() {
    local complete_name=${1:-1}
    local -A docker_image_property
    docker_image_property['prefix_dir']="/home/tong/"
    docker_image_property['project_type']=$(echo $complete_name | cut -d '-' -f1 | head -n 1)
    docker_image_property['project_name']=$(echo $complete_name | cut -d '-' -f2 | head -n 1)
    docker_image_property['service_type']=$(echo $complete_name | cut -d '-' -f3 | head -n 1)
    docker_image_property['resource_name']=$(db_query_property "resource_name" $complete_name)
    docker_image_property['service_port']=$(db_query_property "service_port" $complete_name)
    if [[ ${docker_image_property['service_port']} == "-1" ]]; then
        error_exit "wrong service_port"
    fi
    docker_image_property['service_httpnodePort']=$(db_query_property "service_httpnodePort" $complete_name)
    if [[ ${docker_image_property['service_httpnodePort']} == "-1" ]]; then
        error_exit "wrong service_httpnodePort"
    fi
    docker_image_property['debug_port']=$(db_query_property "debug_port" $complete_name)
    if [[ ${docker_image_property['debug_port']} == "-1" ]] && [[ ${docker_image_property['service_type']} != "vue" ]]; then
        error_exit "wrong debug_port"
    fi
    docker_image_property['debug_httpnodePort']=$(db_query_property "debug_httpnodePort" $complete_name)
    if [[ $debug_httpnodePort == "-1" ]] && [[ ${docker_image_property['service_type']} != "vue" ]]; then
        error_exit "wrong debug_httpnodePort"
    fi
    docker_image_property['service_dir']=$(db_query_property "service_dir" $complete_name)
    if [[ $(echo ${docker_image_property['service_type']} | grep "vue") != "" ]]; then
        #准备vue包
        printf_std "准备vue包"
        cp -r "$project_jenkins_work_path/dist" "$mod_docker_image_path"
        #替换后端地址
        printf_std "替换后端地址"
        local web_server_httpnodePort=$(db_query_property "service_httpnodePort" "${docker_image_property['project_type']}-${docker_image_property['project_name']}-web")
        echo -e "const baseUrl = 'http://172.18.1.190:$web_server_httpnodePort'\nwindow._BASE_URL = baseUrl;" >>$mod_docker_image_path/dist/config.js
        #准备dockerfile
        printf_std "准备dockerfile"
        cp $mod_docker_image_path/mod_files/dockerfile/Dockerfile_vue.dockerfile $mod_docker_image_path/Dockerfile
        sed -i "s#{{service_port}}#${docker_image_property['service_port']}#g" $mod_docker_image_path/Dockerfile
        #准备conf
        printf_std "准备conf"
        cp $mod_docker_image_path/mod_files/nginx/default.conf $mod_docker_image_path
        for key in $(echo ${!docker_image_property[*]}); do
            sed -i "s#{{$key}}#${docker_image_property[$key]}#g" "$mod_docker_image_path/default.conf"
        done
        echo "$complete_name 镜像准备工作完成"
    else
        #准备jar包
        printf_std "准备jar包"
        cp $project_jenkins_work_path/target/*.jar $mod_docker_image_path
        #准备dockerfile
        printf_std "准备dockerfile"
        cp $mod_docker_image_path/mod_files/dockerfile/Dockerfile_server.dockerfile $mod_docker_image_path/Dockerfile
        for key in $(echo ${!docker_image_property[*]}); do
            sed -i "s#{{$key}}#${docker_image_property[$key]}#g" "$mod_docker_image_path/Dockerfile"
        done
        #docker_start.sh
        printf_std "准备docker_start.sh"
        cp $mod_docker_image_path/mod_files/docker_start.sh $mod_docker_image_path
        for key in $(echo ${!docker_image_property[*]}); do
            sed -i "s#{{$key}}#${docker_image_property[$key]}#g" "$mod_docker_image_path/docker_start.sh"
        done
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/docker_start.sh"
        done
        printf_std "$complete_name 镜像准备工作完成"
    fi
}

#配置helm_chart
function configure_helm_chart() {
    local complete_name=${1:-1}
    local project_type=$(echo $complete_name | cut -d '-' -f1 | head -n 1)
    local project_name=$(echo $complete_name | cut -d '-' -f2 | head -n 1)
    local service_type=$(echo $complete_name | cut -d '-' -f3 | head -n 1)
    local app_name=""
    if [[ $(echo $service_type | grep "vue") != "" ]]; then
        #qa124-ctzg-5gucp-web-vue
        app_name="qa124-$project_name-$project_type-web-$service_type"
    else
        #qa124-beidou-ema8-web-server
        app_name="qa124-$project_name-$project_type-$service_type-server"
    fi
    local service_port=$(db_query_property "service_port" $complete_name)
    local service_httpnodePort=$(db_query_property "service_httpnodePort" $complete_name)
    local debug_port=$(db_query_property "debug_port" $complete_name)
    local debug_httpnodePort=$(db_query_property "debug_httpnodePort" $complete_name)
    #修改values.yaml
    printf_std "修改values.yaml"
    sed -i "s#qa124_ema80_mod_server#${app_name}#g" ${mod_chart_prefix_path}/${app_name}/values.yaml
    sed -i "s#service1_port#${service_port}#g" ${mod_chart_prefix_path}/${app_name}/values.yaml
    sed -i "s#service1_httpnodePort#${service_httpnodePort}#g" ${mod_chart_prefix_path}/${app_name}/values.yaml
    if [[ $(echo $service_type | grep "vue") == "" ]]; then
        sed -i "s#service2_port#${debug_port}#g" ${mod_chart_prefix_path}/${app_name}/values.yaml
        sed -i "s#service2_httpnodePort#${debug_httpnodePort}#g" ${mod_chart_prefix_path}/${app_name}/values.yaml
    fi
    #修改Chart.yaml
    printf_std "修改Chart.yaml"
    sed -i "s#project_name#${app_name}#g" ${mod_chart_prefix_path}/${app_name}/Chart.yaml
    #配置/templates/statefulSet.yaml目录挂载
    printf_std "配置/templates/statefulSet.yaml目录挂载"
    #nfs
    cat ${mod_chart_prefix_path}/${app_name}/templates/statefulSet.yaml
}

#配置nacos
function nacos() {
    local project_name=${1:-1}
    local nacos_url=${property['nacos_url']}
    local nacos_auth_url="$nacos_url/dhst/v1/auth/login"
    local nacos_namespace_url="$nacos_url/dhst/v1/console/namespaces?"
    local nacos_config_url="$nacos_url/dhst/v1/cs/configs"
    local nacos_accessToken=$(echo $(curl -s -X POST $nacos_auth_url -d 'username=dahantc&password=dahantc') | jq '.accessToken' | sed 's/\"//g')
    #检查namespace
    printf_std "检查${project_name}的nacos配置"
    local nacos_namespaces=$(echo $(curl -s -X GET $nacos_namespace_url))
    local namespace_quantity=$(echo $nacos_namespaces | jq '.data | length')
    local isNamespaceExist=false
    for i in $(seq 0 $(expr $namespace_quantity - 1)); do
        local temp_namespaceShowName=$(echo $nacos_namespaces | jq '.data['"$i"'].namespaceShowName' | sed 's/\"//g')
        if [[ $temp_namespaceShowName == $project_name ]]; then
            isNamespaceExist=true
            break
        fi
    done
    #创建namespace
    if [[ $isNamespaceExist == true ]]; then
        printf_std "${project_name}的nacos配置已存在"
    else
        printf_std "创建${project_name}的nacos配置"
        local tenant_id=$(date | md5sum | cut -d" " -f1)
        curl -s -X POST "${nacos_namespace_url}customNamespaceId=${tenant_id}&namespaceName=${project_name}&namespaceDesc=&accessToken=${nacos_accessToken}"
        #创建应用配置文件
        local -A db_property
        db_property['hibernate_dialect']="com.dahantc.ema.common.dialect.GroupMySQLDialect"
        db_property['db_url']="${property['db_host']}:${property['db_port']}/qa_5gucp_${project_name}"
        db_property['db_username']="qa_5gucp_${project_name}"
        db_property['db_password']="qa_5gucp_${project_name}"
        db_property['redis_database']=$(db_query_property "redis_database" $complete_name)
        #web
        mkdir -p $mod_docker_image_path/config/nacos/
        cp $mod_docker_image_path/mod_files/nacos/ctc-5gucp-web-mod $mod_docker_image_path/config/nacos/ctc-5gucp-web.properties
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/nacos/ctc-5gucp-web.properties"
        done
        for key in $(echo ${!db_property[*]}); do
            sed -i "s#{{$key}}#${db_property[$key]}#g" "$mod_docker_image_path/config/nacos/ctc-5gucp-web.properties"
        done
        local content=$(cat $mod_docker_image_path/config/nacos/ctc-5gucp-web.properties)
        curl -s -X POST -H "multipart/form-data" -d'tenant='"${tenant_id}"'&dataId=ctc-5gucp-web&group=WEB_GROUP&type=Properties&accessToken='"${nacos_accessToken}"'' --data-urlencode 'content='"${content}"'' $nacos_config_url
        #app
        cp $mod_docker_image_path/mod_files/nacos/ctc-5gucp-app-mod $mod_docker_image_path/config/nacos/ctc-5gucp-app.properties
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/nacos/ctc-5gucp-app.properties"
        done
        for key in $(echo ${!db_property[*]}); do
            sed -i "s#{{$key}}#${db_property[$key]}#g" "$mod_docker_image_path/config/nacos/ctc-5gucp-app.properties"
        done
        content=$(cat $mod_docker_image_path/config/nacos/ctc-5gucp-app.properties)
        curl -s -X POST -H "multipart/form-data" -d'tenant='"${tenant_id}"'&dataId=ctc-5gucp-app&group=APP_GROUP&type=Properties&accessToken='"${nacos_accessToken}"'' --data-urlencode 'content='"${content}"'' $nacos_config_url
        # #创建nacos配置文件
        printf_std "创建${project_name}的nacos注册配置"
        mkdir -p $mod_docker_image_path/config/{web,app}/
        cp $mod_docker_image_path/mod_files/configs_in_docker/5gucp/web/* $mod_docker_image_path/config/web/
        cp $mod_docker_image_path/mod_files/configs_in_docker/5gucp/app/* $mod_docker_image_path/config/app/
        sed -i "s#{{nacos_server}}#$nacos_url#g" "$mod_docker_image_path/config/web/bootstrap.properties"
        sed -i "s#{{nacos_namespace}}#$tenant_id#g" "$mod_docker_image_path/config/web/bootstrap.properties"
        sed -i "s#{{nacos_server}}#$nacos_url#g" "$mod_docker_image_path/config/app/bootstrap.properties"
        sed -i "s#{{nacos_namespace}}#$tenant_id#g" "$mod_docker_image_path/config/app/bootstrap.properties"
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/app/bootstrap.properties"
        done
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/web/bootstrap.properties"
        done
    fi
}

function ema8_config() {
    local project_name=${1:-1}
    local project_type=${2:-1}
    local true_project_type=${3:-1}
    # #创建配置文件
    printf_std "创建${project_name}的应用配置"
    #创建应用配置文件
    local -A db_property
    case "$true_project_type" in
    "ema8") db_property['hibernate_dialect']="org.hibernate.dialect.MySQL55Dialect" ;;
    "ema9") db_property['hibernate_dialect']="com.dahantc.ema.common.dialect.GroupMySQLDialect" ;;
    esac
    db_property['db_url']="${property['db_host']}:${property['db_port']}/qa_${project_type}_${project_name}"
    db_property['db_username']="qa_${project_type}_${project_name}"
    db_property['db_password']="qa_${project_type}_${project_name}"
    # db_property['redis_database']=$(db_query_property "redis_database" $complete_name) 老版本不能配置redis数据库
    mkdir -p $mod_docker_image_path/config/{web,app}/
    cp -r $mod_docker_image_path/mod_files/resource $mod_docker_image_path/config/
    cp $mod_docker_image_path/mod_files/configs_in_docker/ema8/web/* $mod_docker_image_path/config/web/
    cp $mod_docker_image_path/mod_files/configs_in_docker/ema8/app/* $mod_docker_image_path/config/app/
    for key in $(echo ${!property[*]}); do
        sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/web/application.properties"
    done
    for key in $(echo ${!property[*]}); do
        sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/app/application.properties"
    done
    for key in $(echo ${!db_property[*]}); do
        sed -i "s#{{$key}}#${db_property[$key]}#g" "$mod_docker_image_path/config/web/application.properties"
    done
    for key in $(echo ${!db_property[*]}); do
        sed -i "s#{{$key}}#${db_property[$key]}#g" "$mod_docker_image_path/config/app/application.properties"
    done

}

#函数调用备注
case "$1" in
"db_query_property") db_query_property $2 $3 ;;
"git_branch") git_branch $2 ;;
"prepare_for_docker_image") prepare_for_docker_image $2 ;;
"configure_helm_chart") configure_helm_chart $2 ;;
"nacos") nacos $2 ;;
"database") database ;;
*)
    $*
    ;;
esac
