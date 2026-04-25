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

    # Build the full dashboard prefix from HA ingress metadata.
    # Preferred source is X-Ingress-Path. If unavailable, fall back to:
    # 1) X-Forwarded-Prefix, then
    # 2) request URI slug matching "/..._zeroclaw",
    # 3) static value generated at startup.
    map $http_x_ingress_path $ingress_base_path {
        default "";
        ~^(/.+)$ "$1";
    }

    map $http_x_forwarded_prefix $forwarded_prefix_base_path {
        default "";
        ~^(/.+)$ "$1";
    }

    map $request_uri $uri_ingress_base_path {
        default "";
        ~^(/[^/?#]*_zeroclaw)(?:/|$) "$1";
    }

    map $ingress_base_path $resolved_ingress_base_path {
        default "$ingress_base_path";
        ""      "$forwarded_prefix_base_path";
    }

    map $resolved_ingress_base_path $resolved_ingress_base_path_fallback {
        default "$resolved_ingress_base_path";
        ""      "$uri_ingress_base_path";
    }

    map $resolved_ingress_base_path_fallback $dashboard_ingress_path {
        default "$resolved_ingress_base_path_fallback/dashboard";
        ""      "%%ZEROCLAW_PUBLIC_PATH_PREFIX%%";
    }

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

        location = / {
            root /var/www;
            try_files /index.html =404;
        }

        location = /terminal {
            proxy_pass http://ttyd_terminal;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            sub_filter '/terminal/' './';
        }
        location /terminal/ {
            proxy_pass http://ttyd_terminal;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            sub_filter '/terminal/' './';
        }

        location = /landing {
            return 302 ./;
        }

        location = /dashboard {
            proxy_pass http://zeroclaw_daemon%%ZEROCLAW_UPSTREAM_PATH_PREFIX%%/;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Ingress-Path $dashboard_ingress_path;
            proxy_set_header X-Forwarded-Prefix $dashboard_ingress_path;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        location /dashboard/ {
            proxy_pass http://zeroclaw_daemon%%ZEROCLAW_UPSTREAM_PATH_PREFIX%%/;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Ingress-Path $dashboard_ingress_path;
            proxy_set_header X-Forwarded-Prefix $dashboard_ingress_path;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
        }
    }
}
