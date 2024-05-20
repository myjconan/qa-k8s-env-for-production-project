# syntax=docker/dockerfile:1

# FROM 172.18.1.157/public/alpine-for-mod-5gucp:v2
# 基础镜像环境
# FROM 172.18.1.157/java/alpine-jdk8-base:8-jdk-alpine3.7
# RUN apk update
# RUN apk add curl
# RUN apk add mysql-client
# FROM centos:centos7.9.2009
FROM 172.18.1.157/java/openjdk-base:8u332
# 时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# mysql客户端
RUN mkdir -p {{prefix_dir}}/{{service_dir}}/{{service_type}}/
COPY *.rpm {{prefix_dir}}/
# jdk环境
# COPY *.tar.gz {{prefix_dir}}/
# RUN tar -zxvf {{prefix_dir}}/jdk-8u191-linux-x64.tar.gz -C {{prefix_dir}}/
# ENV JAVA_DIR={{prefix_dir}}/jdk1.8.0_191/
# ENV JAVA_HOME=$JAVA_DIR/
# ENV PATH=$PATH:$JAVA_HOME/bin
# 应用
COPY *.jar {{prefix_dir}}/{{service_dir}}/{{service_type}}/
COPY docker_start.sh {{prefix_dir}}/{{service_dir}}/
COPY BOOT-INF/ {{prefix_dir}}/{{service_dir}}/{{service_type}}/BOOT-INF/
COPY config/ {{prefix_dir}}/config/
RUN chmod +x {{prefix_dir}}/{{service_dir}}/docker_start.sh
ENTRYPOINT ["sh","{{prefix_dir}}/{{service_dir}}/docker_start.sh"]
EXPOSE {{service_port}} {{debug_port}}
