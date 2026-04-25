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

        # Common Proxy Headers for Home Assistant Ingress
        proxy_http_version 1.1;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
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
        location = %%ZEROCLAW_PATH_PREFIX%% {
            proxy_pass http://zeroclaw_daemon;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Forwarded-Prefix $http_x_ingress_path%%ZEROCLAW_PATH_PREFIX%%;
            proxy_set_header X-Ingress-Path $http_x_ingress_path;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_redirect ~^(/.*)$ $http_x_ingress_path$1;
            proxy_redirect ~^https?://[^/]+(?::\d+)?(/.*)$ $scheme://$http_host$1;

            sub_filter '<head>' '<head>\n<base href="./">';
            sub_filter 'href="/_app/' 'href="./_app/';
            sub_filter 'src="/_app/' 'src="./_app/';
            sub_filter '"/_app/' '"./_app/';
            sub_filter 'href="/favicon' 'href="./favicon';
            sub_filter 'src="/favicon' 'src="./favicon';
        }
        location %%ZEROCLAW_PATH_PREFIX%%/ {
            proxy_pass http://zeroclaw_daemon;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Forwarded-Prefix $http_x_ingress_path%%ZEROCLAW_PATH_PREFIX%%;
            proxy_set_header X-Ingress-Path $http_x_ingress_path;
            proxy_set_header X-Forwarded-Uri $request_uri;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_redirect ~^(/.*)$ $http_x_ingress_path$1;
            proxy_redirect ~^https?://[^/]+(?::\d+)?(/.*)$ $scheme://$http_host$1;

            # ZeroClaw still emits some absolute asset URLs, so keep them inside
            # the current Home Assistant ingress path instead of sending them to
            # the HA root where they 404.
            sub_filter '<head>' '<head>\n<base href="./">';
            sub_filter 'href="/_app/' 'href="./_app/';
            sub_filter 'src="/_app/' 'src="./_app/';
            sub_filter '"/_app/' '"./_app/';
            sub_filter 'href="/favicon' 'href="./favicon';
            sub_filter 'src="/favicon' 'src="./favicon';
        }

        # Legacy API support
        location /api/ {
            proxy_pass http://zeroclaw_daemon/api/;
            proxy_set_header Authorization "Bearer %%ZEROCLAW_INGRESS_TOKEN%%";
            proxy_set_header X-Forwarded-Prefix $http_x_ingress_path%%ZEROCLAW_PATH_PREFIX%%;
            proxy_set_header X-Ingress-Path $http_x_ingress_path;
            proxy_redirect ~^(/.*)$ $http_x_ingress_path$1;
            proxy_redirect ~^https?://[^/]+(?::\d+)?(/.*)$ $scheme://$http_host$1;
        }

        location = /health {
            access_log off;
            return 200 "OK\n";
        }
    }
}
