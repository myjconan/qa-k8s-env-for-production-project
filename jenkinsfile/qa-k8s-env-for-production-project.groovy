//公司系统参数
// def harbor="172.18.1.157"
// def chart_base="/home/k8s/chart"
// def env.build_workpath="/home/k8s/build/project_image"
//----------------------------------------------------------------------------------------
//build with parameters参数
// JOB_NAME
// project_type=ema8
// project_name=beidou
// service_type=vue,web,app
// git_path=gitlab……
// branch_for_git # git_branch为git插件系统变量，不能使用
//----------------------------------------------------------------------------------------
//公司参数
def harbor_url = '172.18.1.157'
def mod_chart_prefix_path = '/home/k8s/chart/124-qa/'
//自定义参数
def mod_git_base = '/var/jenkins_home/jobs/qa-k8s-env-for-production-project/mod_git_base'
def build_script = "${mod_git_base}/jenkinsfile/qa-k8s-env-for-production-project.sh"
def mod_docker_image_path = '/home/k8s/build/project_image/qa-k8s-env-for-production-project-mod-server/'
def complete_name = "${project_type}-${project_name}-${service_type}"
def true_project_type = 'ema8'
if ("${project_type}" == '5gucp') {
    if (branch_for_git.contains('release/9')) {
        true_project_type = 'ema9'
    }else {
        true_project_type = '5gucp'
    }
}

def app_name
def chart_mod
if ("${service_type}" != 'vue') {
    // qa124-beidou-ema8-web-server
    app_name = "qa124-$project_name-$project_type-$service_type-server"
    chart_mod = 'qa124-project-ema80-mod-server'
} else {
    // qa124-leapauto-5gucp-web-vue
    app_name = "qa124-$project_name-$project_type-web-$service_type"
    chart_mod = 'qa124-project-ema80-mod-vue'
}
def is_uninstall = false
if (params.uninstall_app.toUpperCase() == 'DELETE') {
    is_uninstall = true
}

pipeline {
    agent any

    stages {
        stage('卸载应用') {
            when { expression { is_uninstall == true } }
            steps {
                script {
                    is_installed = sh(
                        script: "/usr/bin/helm list --namespace mod-5gucp --kubeconfig /home/k8s/config | grep ${app_name} | wc -l",
                        returnStdout: true
                    ).trim()
                    if ("${is_installed}" == '1') {
                        sh "/usr/bin/helm uninstall ${app_name} --namespace mod-5gucp --kubeconfig /home/k8s/config"
                        echo "${app_name}已卸载！"
                    } else {
                        echo "${app_name}未安装，无需卸载！"
                    }
                }
            }
        }
        stage('打印构建参数') {
            when { expression { is_uninstall != true } }
            steps {
                //自定义
                echo "构建应用名称：${app_name}"
                echo "git路径：${git_path}"
                echo "git分支：${branch_for_git}"
            }
        }

        stage('初始化构建') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    echo '创建mod_git_base目录'
                    sh "mkdir -p ${mod_git_base}"
                    sh "bash ${build_script} init_build"
                }
            }
        }

        stage('拉取应用git源码') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    git branch: "${branch_for_git}", url: "git@${git_path}"
                }
            }
        }

        stage('源码构建') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    if ("${service_type}" == 'vue') {
                        echo 'npm构建'
                        sh 'npm i && npm run build:test'
                    } else {
                        echo 'mvn构建'
                        sh 'mvn clean package'
                    }
                }
            }
        }

        stage('应用配置') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    if ("${true_project_type}" == '5gucp') {
                        sh "bash ${build_script} nacos ${project_name}"
                    } else {
                        sh "bash ${build_script} ema8_config ${project_name} ${project_type} ${true_project_type}"
                    }
                }
            }
        }

        stage('准备镜像构建') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    sh "bash ${build_script} prepare_for_docker_image ${complete_name}"
                }
            }
        }

        stage('构建镜像') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    sh "docker build -t '${harbor_url}/public/${app_name}:v1' ${mod_docker_image_path}/"
                }
            }
        }

        stage('镜像上传至harbor') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    sh " docker push '${harbor_url}/public/${app_name}:v1'"
                }
            }
        }

        stage('创建helm_chart') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    is_chart_exist = sh(
                        script: "cd ${mod_chart_prefix_path} && ls |grep ${app_name}|wc -l",
                        returnStdout: true
                    ).trim()
                    if ("${is_chart_exist}" == '0') {
                        sh "cp -r ${mod_chart_prefix_path}/${chart_mod}/ ${mod_chart_prefix_path}/${app_name}"
                    }
                }
            }
        }

        stage('配置helm_chart') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    sh "bash ${build_script} configure_helm_chart ${complete_name}"
                }
            }
        }

        stage('装载至k8s') {
            when { expression { is_uninstall != true } }
            steps {
                script {
                    is_installed = sh(
                        script: "/usr/bin/helm list --namespace mod-5gucp --kubeconfig /home/k8s/config|grep ${app_name}|wc -l",
                        returnStdout: true
                    ).trim()
                    if ("${is_installed}" == '0') {
                        sh "/usr/bin/helm install ${app_name} ${mod_chart_prefix_path}/${app_name} --namespace mod-5gucp --kubeconfig /home/k8s/config"
                    } else {
                        sh "/usr/bin/helm upgrade ${app_name} ${mod_chart_prefix_path}/${app_name} --namespace mod-5gucp --kubeconfig /home/k8s/config --recreate-pods"
                    }
                }
            }
        }
    }
}
