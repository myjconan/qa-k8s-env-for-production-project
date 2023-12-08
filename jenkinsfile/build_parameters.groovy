//project_type
def list=" bash  /var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh db_query_project_type_all".execute().in.text;
def alist=[];
list.split(",").each{
    alist.add(it)
}
return alist;
//project_name

//service_type

//git_path

//git_branch