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

            # 1. Inject a base tag to fix all asset loading (CSS/JS/Images) cleanly
            sub_filter '<head>' '<head>\n<base href="$http_x_ingress_path/zeroclaw/">';

            # 2. Overwrite the React Router default basename you found in the code
            sub_filter 'basename: n="./"' 'basename: n="$http_x_ingress_path/zeroclaw/"';

            # Ensure sub_filter applies to everything and replaces all instances
            sub_filter_once off;
            sub_filter_types *;
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
