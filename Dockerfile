FROM nginx:alpine
COPY webapp1/ /usr/share/nginx/html
COPY webapp2/ /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
