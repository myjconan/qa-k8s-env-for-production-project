//project_type
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_project_type_all".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;

//project_name
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_stripped_project_name_in_project_type ${project_type}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;

//service_type
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_service_type_in_project_type ${project_type}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;

//git_path
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_property ${project_type}-${project_name}-${service_type}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;
//git_branch
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh git_branch ${project_type}-${project_name}-${service_type}".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;