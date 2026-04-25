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

        # Common Proxy Headers for Home Assistant Ingress
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_set_header Accept-Encoding ""; # Required for sub_filter to work on compressed responses

        # Global Sub-Filter Settings
        sub_filter_types *;
        sub_filter_once off;

        location = / {
            root /var/www;
            try_files /index.html =404;
        }

        # Terminal Location
        location = /terminal { return 302 terminal/; }
        location /terminal/ {
            proxy_pass http://ttyd_terminal;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            # Ensure internal terminal paths resolve relative to the current Ingress URL
            sub_filter '/terminal/' './';
        }

        # Dashboard Location
        location /zeroclaw/ {
            proxy_pass http://zeroclaw_daemon/;

            # Fix React Router basename to match the HA ingress path
            sub_filter 'basename:"/"' 'basename:"$http_x_ingress_path/zeroclaw/"';
            sub_filter 'basename: "/"' 'basename: "$http_x_ingress_path/zeroclaw/"';

            # Fix asset paths to be relative
            sub_filter '="/' '="./';
            sub_filter "='/" "='./";
        }

        # Legacy API support
        location /api/ {
            proxy_pass http://zeroclaw_daemon/api/;
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
        }
    }
}
