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

        location = / {
            root /var/www;
            try_files /index.html =404;
        }

        location = /terminal { return 302 /terminal/; }
        location /terminal/ {
            proxy_pass http://ttyd_terminal/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_buffering off;
        }

        location /zeroclaw/ {
            proxy_pass http://zeroclaw_daemon/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_buffering off;
        }

        location /api/ {
            proxy_pass http://zeroclaw_daemon/api/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_buffering off;
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
        }
    }
}
