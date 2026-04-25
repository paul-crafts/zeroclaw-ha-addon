worker_processes 1;
pid /var/run/nginx.pid;
error_log stderr warn;

events {
    worker_connections 256;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    absolute_redirect off;
    port_in_redirect off;

    log_format minimal '$remote_addr - $request_uri $status';
    access_log /dev/stdout minimal;

    upstream zeroclaw_daemon {
        server 127.0.0.1:%%ZEROCLAW_PORT%%;
    }

    upstream ttyd_terminal {
        server 127.0.0.1:%%TTYD_PORT%%;
    }

    server {
        listen %%INGRESS_PORT%%;
        server_name _;

        proxy_http_version 1.1;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_buffering off;
        proxy_set_header Accept-Encoding "";

        sub_filter_types *;
        sub_filter_once off;

        location = /landing {
            root /var/www;
            try_files /index.html =404;
        }

        location = /terminal { return 302 terminal/; }
        location /terminal/ {
            proxy_pass http://ttyd_terminal;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            sub_filter '/terminal/' './';
        }

        location = / {
            proxy_pass http://zeroclaw_daemon;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Ingress-Path $http_x_ingress_path;
            proxy_set_header X-Forwarded-Prefix $http_x_ingress_path;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_redirect ~^(/.*)$ $scheme://$http_host$http_x_ingress_path$1;
            proxy_redirect ~^https?://[^/]+(?::\d+)?(/.*)$ $scheme://$http_host$http_x_ingress_path$1;
        }

        location / {
            proxy_pass http://zeroclaw_daemon;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Ingress-Path $http_x_ingress_path;
            proxy_set_header X-Forwarded-Prefix $http_x_ingress_path;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_redirect ~^(/.*)$ $scheme://$http_host$http_x_ingress_path$1;
            proxy_redirect ~^https?://[^/]+(?::\d+)?(/.*)$ $scheme://$http_host$http_x_ingress_path$1;
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
        }
    }
}
