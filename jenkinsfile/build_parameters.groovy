//project_type
//Active Choices Parameter
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_project_type_all".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;


//project_name
//请选择项目名称，如未收录，请联系运维人员添加！！！
//Active Choices Reactive Parameter
//project_type
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_stripped_project_name_in_project_type ${project_type}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;

//service_type
//Active Choices Reactive Parameter
//project_type,project_name
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_service_type_in_project ${project_type} ${project_name}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;

//git_path
//Active Choices Reactive Parameter
//project_name,service_type
return [" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_property git_path ${project_name}-${service_type}".execute().in.text]

//git_branch
//请耐心等待几秒后选择！！！
//Active Choices Reactive Parameter
//project_name,service_type
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh git_branch  ${project_name}-${service_type}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;