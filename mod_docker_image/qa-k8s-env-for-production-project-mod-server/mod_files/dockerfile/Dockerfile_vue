# syntax=docker/dockerfile:1

FROM nginx
RUN mkdir -p /home/dahantc/ema8/emaWeb01/
RUN rm /etc/nginx/conf.d/default.conf
ADD default.conf /etc/nginx/conf.d/
COPY dist/ /home/dahantc/ema8/emaWeb01/dist/
EXPOSE {{service_port}}
