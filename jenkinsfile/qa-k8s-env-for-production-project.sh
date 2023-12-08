#! /bin/bash
#全局路径
project_database="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/database/qa-k8s-env-for-production-project-database.csv"
mod_docker_image_path="/home/k8s/build/project_image/qa-k8s-env-for-production-project-mod-server"
#构建目录
jar_path="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/workspace/target"
vue_path="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/workspace/"
#helm chart目录
project_chart_dir="/home/k8s/chart/124-qa"

function error_exit() {
    echo -e "$1" 1>&2
    exit 1
}

#数据库相关
function database() {

}

function db_query_project_type_all() {
    local col_name="project_name"
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    echo $(awk -F "," 'NR>1{print $'"$col_num"'}' $project_database | cut -d '-' -f1 | sort -u)
}

function db_query_stripped_project_name_in_project_type() {
    local project_type=${1:-1}
    local col_name="project_name"
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    echo $(awk -F "," -v col_num=$col_num 'NR>1{print $col_num}' $project_database | grep $project_type | cut -d '-' -f2 | sort -u)
}

function db_query_service_type_in_project_type() {
    local project_type=${1:-1}
    local col_name="project_name"
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    echo $(awk -F "," -v col_num=$col_num 'NR>1{print $col_num}' $project_database | grep $project_type | cut -d '-' -f3 | sort -u)
}

function db_query_property() {
    local col_name=${1:-1}
    local project_name=${2:-1}
    local col_num=$(echo $(head -n 1 $project_database | awk -F "," -v col_name=$col_name '{ for (i=1; i<=NF; i++) if ($i == col_name) print i }'))
    if [[ $col_num == "" ]]; then
        error_exit "bad query variable:\ncol_name:$col_name\nproject_name:$project_name"
    else
        echo $(grep $project_name $project_database | grep -v plugin | cut -d ',' -f$col_num | head -n 1)
    fi
}

#获取git分支
function git_branch() {
    local token="wjUT7QBsL5vsL-ytGJUr"
    local gitlab_url="gitlab.dahantc.com"
    local project_name=${1:-1}
    local project_id=$(db_query_property "git_id" $project_name)
    for i in $(seq 1 11); do
        local branch_list=$(curl -s --header "PRIVATE-TOKEN: ${token}" "http://gitlab.dahantc.com/api/v4/projects/${project_id}/repository/branches?per_page=200&page=$i" | jq -r ".[].name" | grep -Ev "master" | tr "\n" "," | sed 's/,$//g')
        echo "master",$branch_list
    done
}

#准备镜像
function prepare_for_docker_image() {
    local prefix_dir="/home/tong/"
    local complete_name=${1:-1}
    local project_type=$(echo $complete_name | cut -d '-' -f1 | head -n 1)
    local project_name=$(echo $complete_name | cut -d '-' -f2 | head -n 1)
    local service_type=$(echo $complete_name | cut -d '-' -f3 | head -n 1)
    local resource_name=$(db_query_property "resource_name" $complete_name)
    local service_port=$(db_query_property "service_port" $complete_name)
    if [[ $service_port == "-1" ]]; then
        error_exit "wrong service_port"
    fi
    local service_httpnodePort=$(db_query_property "service_httpnodePort" $complete_name)
    if [[ $service_httpnodePort == "-1" ]]; then
        error_exit "wrong service_httpnodePort"
    fi
    local debug_port=$(db_query_property "debug_port" $complete_name)
    if [[ $debug_port == "-1" ]] && [[ $service_type != "vue" ]]; then
        error_exit "wrong debug_port"
    fi
    local debug_httpnodePort=$(db_query_property "debug_httpnodePort" $complete_name)
    if [[ $debug_httpnodePort == "-1" ]] && [[ $service_type != "vue" ]]; then
        error_exit "wrong debug_httpnodePort"
    fi
    local service_dir=$(db_query_property "service_dir" $complete_name)

    # echo "清除上次构建残留"
    # #清除上次构建jar包
    # local files=$(cd $mod_docker_image_path && ls *.jar 2>/dev/null | wc -l)
    # if [ "$files" != "0" ]; then
    #     rm $mod_docker_image_path/*.jar
    # fi
    # #清除上次构建vue包
    # files=$(cd $mod_docker_image_path && ls | grep dist 2>/dev/null | wc -l)
    # if [ "$files" != "0" ]; then
    #     rm -rf "$mod_docker_image_path/dist"
    #     rm "$mod_docker_image_path/default.conf"
    # fi
    # #清除上次构建Dockerfile
    # files=$(cd $mod_docker_image_path && ls | grep Dockerfile 2>/dev/null | wc -l)
    # if [ "$files" != "0" ]; then
    #     rm "$mod_docker_image_path/Dockerfile"
    # fi
    # #清除上次构建配置文件
    # files=$(cd $mod_docker_image_path && ls | grep config 2>/dev/null | wc -l)
    # if [ "$files" != "0" ]; then
    #     rm -rf "$mod_docker_image_path/config"
    #     mkdir -p "$mod_docker_image_path/config"
    # fi
    if [[ $(echo $service_type | grep "vue") != "" ]]; then
        #准备vue包
        cp -r "$vue_path/dist" "$mod_docker_image_path"
        #替换后端地址
        local web_server_httpnodePort=$(db_query_property "service_httpnodePort" "${project_type}-${project_name}-web")
        echo -e "const baseUrl = 'http://172.18.1.190:$web_server_httpnodePort'\nwindow._BASE_URL = baseUrl;" >>$mod_docker_image_path/dist/config.js
        #准备dockerfile
        cp $mod_docker_image_path/mod_files/dockerfile/Dockerfile_vue $mod_docker_image_path/Dockerfile
        sed -i 's#{{service_port}}#$service_port#' $mod_docker_image_path/Dockerfile
        #准备conf
        cp $mod_docker_image_path/mod_files/nginx/default.conf $mod_docker_image_path
        echo "$complete_name 镜像准备工作完成"
    else
        #准备jar包
        cp $jar_path/*.jar $mod_docker_image_path
        #准备dockerfile
        cp $mod_docker_image_path/mod_files/dockerfile/Dockerfile_server $mod_docker_image_path/Dockerfile
        sed -i "s#{{prefix_dir}}#$prefix_dir#g" $mod_docker_image_path/Dockerfile
        sed -i "s#{{service_type}}#$service_type#g" $mod_docker_image_path/Dockerfile
        sed -i "s#{{service_dir}}#$service_dir#g" $mod_docker_image_path/Dockerfile
        sed -i "s#{{service_port}}#$service_port#g" $mod_docker_image_path/Dockerfile
        sed -i "s#{{debug_port}}#$service_port#g" $mod_docker_image_path/Dockerfile
        #docker_start.sh
        cp $mod_docker_image_path/mod_files/docker_start.sh $mod_docker_image_path
        sed -i "s#{{prefix_dir}}#$prefix_dir#g" $mod_docker_image_path/docker_start.sh
        sed -i "s#{{service_dir}}#$service_dir#g" $mod_docker_image_path/docker_start.sh
        sed -i "s#{{service_type}}#$service_type#g" $mod_docker_image_path/docker_start.sh
        sed -i "s#{{project_type}}#$project_type#g" $mod_docker_image_path/docker_start.sh
        sed -i "s#{{resource_name}}#$resource_name#g" $mod_docker_image_path/docker_start.sh
        sed -i "s#{{debug_port}}#$debug_port#g" $mod_docker_image_path/docker_start.sh
        sed -i "s#{{project_name}}#$project_name#g" $mod_docker_image_path/docker_start.sh
        echo "$complete_name 镜像准备工作完成"
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
    sed -i "s#qa124_ema80_mod_server#${app_name}#g" ${project_chart_dir}/${app_name}/values.yaml
    sed -i "s#service1_port#${service_port}#g" ${project_chart_dir}/${app_name}/values.yaml
    sed -i "s#service1_httpnodePort#${service_httpnodePort}#g" ${project_chart_dir}/${app_name}/values.yaml
    if [[ $(echo $service_type | grep "vue") == "" ]]; then
        sed -i "s#service2_port#${debug_port}#g" ${project_chart_dir}/${app_name}/values.yaml
        sed -i "s#service2_httpnodePort#${debug_httpnodePort}#g" ${project_chart_dir}/${app_name}/values.yaml
    fi
    #修改Chart.yaml
    sed -i "s#project_name#${app_name}#g" ${project_chart_dir}/${app_name}/Chart.yaml
    #配置/templates/statefulSet.yaml目录挂载
    #nfs
    cat ${project_chart_dir}/${app_name}/templates/statefulSet.yaml
}

#配置nacos
function nacos() {
    local nacos_url="http://172.18.9.190:31876"
    local nacos_auth_url="$nacos_url/dhst/v1/auth/login"
    local nacos_namespace_url="$nacos_url/dhst/v1/console/namespaces?"
    local nacos_config_url="$nacos_url/dhst/v1/cs/configs"
    local nacos_accessToken=$(echo $(curl -s -X POST $nacos_auth_url -d 'username=dahantc&password=dahantc') | jq '.accessToken' | sed 's/\"//g')
    local project_name=${1:-1}
    #检查namespace
    echo "检查${project_name}的nacos配置"
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
        echo "${project_name}的nacos配置已存在"
    else
        echo "创建${project_name}的nacos配置"
        local tenant_id=$(date | md5sum | cut -d" " -f1)
        curl -s -X POST "${nacos_namespace_url}customNamespaceId=${tenant_id}&namespaceName=${project_name}&namespaceDesc=&accessToken=${nacos_accessToken}"
        #创建应用配置文件
        local -A property
        property['db_url']="172.18.1.190:30336/qa_5gucp_${project_name}"
        property['db_username']="qa_5gucp_${project_name}"
        property['db_password']="qa_5gucp_${project_name}"
        property['redis_address']="redis://172.18.1.190:31873"
        property['redis_password']="test"
        property['minio_api_url']="http://172.18.1.190:31874"
        property['minio_accessKey']="admin"
        property['minio_secretKey']="root123456"
        #web
        mkdir -p $mod_docker_image_path/config/nacos/
        cp $mod_docker_image_path/mod_files/nacos/ctc-5gucp-web-mod $mod_docker_image_path/config/nacos/ctc-5gucp-web.properties
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/nacos/ctc-5gucp-web.properties"
        done
        local content=$(cat $mod_docker_image_path/config/nacos/ctc-5gucp-web.properties)
        curl -s -X POST -H "multipart/form-data" -d'tenant='"${tenant_id}"'&dataId=ctc-5gucp-web&group=WEB_GROUP&type=Properties&accessToken='"${nacos_accessToken}"'' --data-urlencode 'content='"${content}"'' $nacos_config_url
        #app
        cp $mod_docker_image_path/mod_files/nacos/ctc-5gucp-app-mod $mod_docker_image_path/config/nacos/ctc-5gucp-app.properties
        for key in $(echo ${!property[*]}); do
            sed -i "s#{{$key}}#${property[$key]}#g" "$mod_docker_image_path/config/nacos/ctc-5gucp-app.properties"
        done
        content=$(cat $mod_docker_image_path/config/nacos/ctc-5gucp-app.properties)
        curl -s -X POST -H "multipart/form-data" -d'tenant='"${tenant_id}"'&dataId=ctc-5gucp-app&group=APP_GROUP&type=Properties&accessToken='"${nacos_accessToken}"'' --data-urlencode 'content='"${content}"'' $nacos_config_url
        # #创建nacos配置文件
        echo "创建${project_name}的nacos注册配置"
        mkdir -p $mod_docker_image_path/config/{web,app}/
        cp $mod_docker_image_path/mod_files/configs_in_docker/5gucp/web/* $mod_docker_image_path/config/web/
        cp $mod_docker_image_path/mod_files/configs_in_docker/5gucp/app/* $mod_docker_image_path/config/app/
        sed -i "s#{{nacos_server}}#$nacos_url#g" "$mod_docker_image_path/config/web/bootstrap.properties"
        sed -i "s#{{nacos_namespace}}#$tenant_id#g" "$mod_docker_image_path/config/web/bootstrap.properties"
        sed -i "s#{{nacos_server}}#$nacos_url#g" "$mod_docker_image_path/config/app/bootstrap.properties"
        sed -i "s#{{nacos_namespace}}#$tenant_id#g" "$mod_docker_image_path/config/app/bootstrap.properties"
    fi

}

#执行方法调用
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
