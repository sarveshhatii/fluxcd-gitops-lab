FROM nginx:alpine

COPY website/index.html /usr/share/nginx/html/index.html
COPY website/style.css /usr/share/nginx/html/style.css

EXPOSE 80
