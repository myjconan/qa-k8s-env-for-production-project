//公司系统参数
// def harbor="172.18.1.157"
// def chart_base="/home/k8s/chart"
// def env.build_workpath="/home/k8s/build/project_image"
//----------------------------------------------------------------------------------------
//build with parameters参数
// JOB_NAME
// project_type=ema8
// project_name=beidou
// server_type=vue,web,app
// git_path=gitlab……
// git_branch
//----------------------------------------------------------------------------------------
//自定义参数
def build_script="/var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base/jenkinsfile/qa-k8s-env-for-production-project.sh"
def harbor_url="172.18.1.157"
def mod_docker_image_prefix_path="/home/k8s/build/project_image/"
def mod_chart_prefix_path="/home/k8s/chart/124-qa/"
def complete_name="${project_type}-${project_name}-${server_type}"
def app_name
if( "${server_type}" != "vue" ){
    // qa124-beidou-ema8-web-server
    app_name="qa124-$project_name-$project_type-$server_type-server"
    chart_mod="qa124-project-ema80-mod-server"
}else{
    // qa124-leapauto-5gucp-web-vue
    app_name="qa124-$project_name-$project_type-web-$server_type"
    chart_mod="qa124-project-ema80-mod-vue"
}

pipeline {
    agent any

    stages {
        stage('打印参数') {
            steps {
                //自定义
                echo "构建应用名称：${app_name}"
                echo "git路径：${git_path}"
                echo "git分支：${git_branch}"
            }
        }

        stage('初始化构建') {
            steps{
				script{
                    sh "bash ${build_script} init_build"
                }            
            }
        }

        stage('拉取应用git源码') {
            steps{
				script{
					git branch: "${git_branch}", url: "git@${git_path}"
                }            
            }
        }

        stage('源码构建'){
            steps{
                script{
                    if( "${server_type}" == "vue" ){
                        echo "npm构建"
                        sh "npm i && npm run build:test"
                    } else {
                        echo "mvn构建"
                        sh "mvn clean package"
                    }
                }
            }
        }

        stage('准备镜像构建'){
            steps{
                script{
                    sh "bash ${build_script} prepare_for_docker_image ${complete_name}"
                }
            }
        }

        stage('构建镜像'){
            steps{
				script{
					sh "docker build -t '${harbor_url}/public/${app_name}:v1' ${mod_docker_image_prefix_path}"
				}
            }
        }

        stage('镜像上传至harbor'){
            steps{
				script{
                    sh " docker push '${harbor_url}/public/${app_name}:v1'"
				}
            }
        }

        stage('创建helm_chart'){
            steps {
                script{
                    is_chart_exist=sh(
                        script: "cd ${mod_chart_prefix_path} && ls |grep ${app_name}|wc -l",
                        returnStdout: true
                    ).trim()
                    if( "${is_chart_exist}" == "0" ){
                        sh "cp -r ${mod_chart_prefix_path}/${chart_mod}/ ${mod_chart_prefix_path}/${app_name}"
                    }
                }
            }
        }

        stage('配置helm_chart'){
            steps {
                script{
                    sh "bash ${build_script} configure_helm_chart ${complete_name}"
                }
            }
        }

        stage('装载至k8s'){
            steps{
                script{
                    is_install=sh(
                        script: "/usr/bin/helm list --namespace mod-5gucp --kubeconfig /home/k8s/config|grep ${app_name}|wc -l",
                        returnStdout: true
                    ).trim()
                    if( "${is_install}" == "0" ){
                        sh "/usr/bin/helm install ${app_name} ${mod_chart_prefix_path}/${app_name} --namespace mod-5gucp --kubeconfig /home/k8s/config"
                    }else{
                        sh "/usr/bin/helm upgrade ${app_name} ${mod_chart_prefix_path}/${app_name} --namespace mod-5gucp --kubeconfig /home/k8s/config"
                    }
                }
            }
        }
    }
}