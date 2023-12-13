/* groovylint-disable DeadCode, LineLength, NglParseError, VariableTypeRequired */
//生产项目k8s测试环境构建（非信创）。支持ema8、5gucp9.4x、5gucp10.5x项目类型。
//project_type
//Active Choices Parameter
def list = ' bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_project_type_all'.execute().in.text
def alist = []
list.split(',').each {
    alist.add(it)
}
return alist

//project_name
//请选择项目名称，如未收录，请联系运维人员添加！！！配置项需读取数据库，请耐心等待！！！可在下方筛选器中快速搜索。
//Active Choices Reactive Parameter
//project_type
def list = " bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_stripped_project_name_in_project_type ${project_type}".execute().in.text
def alist = []
list.split(',').each {
    alist.add(it)
}
return alist

//service_type
//配置项需读取数据库，请耐心等待！！！
//Active Choices Reactive Parameter
//project_type,project_name
def list = " bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_service_type_in_project ${project_type} ${project_name}".execute().in.text
def alist = []
list.split(',').each {
    alist.add(it)
}
return alist

//git_path
//Active Choices Reactive Parameter
//project_type,project_name,service_type
return [" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_property git_path ${project_type}-${project_name}-${service_type}".execute().in.text]

// branch_for_git // git_branch为git插件系统变量，不能使用
//配置项需读取数据库，请耐心等待！！！可在下方筛选器中快速搜索。
//Active Choices Reactive Parameter
//project_type,project_name,service_type
def list = " bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh git_branch ${project_type}-${project_name}-${service_type}".execute().in.text
def alist = []
list.split(',').each {
    alist.add(it)
}
return alist
