plugin_paths = { "/usr/share/jitsi-meet/prosody-plugins/" }

-- domain mapper options, must at least have domain base set to use the mapper
muc_mapper_domain_base = "{{SUBDOMAIN.DOMAIN.TLD}}";

external_service_secret = "{{EXTERNAL_SERVICE_SECRET}}";
external_services = {
     { type = "stun", host = "{{SUBDOMAIN.DOMAIN.TLD}}", port = 3478 },
     { type = "turn", host = "{{SUBDOMAIN.DOMAIN.TLD}}", port = 3478, transport = "udp", secret = true, ttl = 86400, algorithm = "turn" },
     { type = "turns", host = "{{SUBDOMAIN.DOMAIN.TLD}}", port = 5349, transport = "tcp", secret = true, ttl = 86400, algorithm = "turn" }
};

cross_domain_bosh = false;
consider_bosh_secure = true;
-- https_ports = { }; -- Remove this line to prevent listening on port 5284

-- by default prosody 0.12 sends cors headers, if you want to disable it uncomment the following (the config is available on 0.12.1)
--http_cors_override = {
--    bosh = {
--        enabled = false;
--    };
--    websocket = {
--        enabled = false;
--    };
--}

-- https://ssl-config.mozilla.org/#server=haproxy&version=2.1&config=intermediate&openssl=1.1.0g&guideline=5.4
ssl = {
    protocol = "tlsv1_2+";
    ciphers = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"
}

unlimited_jids = {
    "focus@auth.{{SUBDOMAIN.DOMAIN.TLD}}",
    "jvb@auth.{{SUBDOMAIN.DOMAIN.TLD}}"
}

VirtualHost "{{SUBDOMAIN.DOMAIN.TLD}}"
    authentication = "internal_hashed" -- do not delete me
    -- Properties below are modified by jitsi-meet-tokens package config
    -- and authentication above is switched to "token"
    --app_id="example_app_id"
    --app_secret="example_app_secret"
    -- Assign this host a certificate for TLS, otherwise it would use the one
    -- set in the global section (if any).
    -- Note that old-style SSL on port 5223 only supports one certificate, and will always
    -- use the global one.
    ssl = {
        key = "/etc/prosody/certs/{{SUBDOMAIN.DOMAIN.TLD}}.key";
        certificate = "/etc/prosody/certs/{{SUBDOMAIN.DOMAIN.TLD}}.crt";
    }
    av_moderation_component = "avmoderation.{{SUBDOMAIN.DOMAIN.TLD}}"
    speakerstats_component = "speakerstats.{{SUBDOMAIN.DOMAIN.TLD}}"
    conference_duration_component = "conferenceduration.{{SUBDOMAIN.DOMAIN.TLD}}"
    end_conference_component = "endconference.{{SUBDOMAIN.DOMAIN.TLD}}"
    -- we need bosh
    modules_enabled = {
        "bosh";
        "pubsub";
        "ping"; -- Enable mod_ping
        "speakerstats";
        "external_services";
        "conference_duration";
        "end_conference";
        "muc_lobby_rooms";
        "muc_breakout_rooms";
        "av_moderation";
        "room_metadata";
    }
    c2s_require_encryption = false
    lobby_muc = "lobby.{{SUBDOMAIN.DOMAIN.TLD}}"
    breakout_rooms_muc = "breakout.{{SUBDOMAIN.DOMAIN.TLD}}"
    room_metadata_component = "metadata.{{SUBDOMAIN.DOMAIN.TLD}}"
    main_muc = "conference.{{SUBDOMAIN.DOMAIN.TLD}}"
    -- muc_lobby_whitelist = { "recorder.{{SUBDOMAIN.DOMAIN.TLD}}" } -- Here we can whitelist jibri to enter lobby enabled rooms

VirtualHost "guest.{{SUBDOMAIN.DOMAIN.TLD}}"
    authentication = "anonymous"
    c2s_require_encryption = false

Component "conference.{{SUBDOMAIN.DOMAIN.TLD}}" "muc"
    restrict_room_creation = true
    storage = "memory"
    modules_enabled = {
        "muc_hide_all";
        "muc_meeting_id";
        "muc_domain_mapper";
        "polls";
        --"token_verification";
        "muc_rate_limit";
        "muc_password_whitelist";
    }
    admins = { "focus@auth.{{SUBDOMAIN.DOMAIN.TLD}}" }
    muc_password_whitelist = {
        "focus@auth.{{SUBDOMAIN.DOMAIN.TLD}}"
    }
    muc_room_locking = false
    muc_room_default_public_jids = true

Component "breakout.{{SUBDOMAIN.DOMAIN.TLD}}" "muc"
    restrict_room_creation = true
    storage = "memory"
    modules_enabled = {
        "muc_hide_all";
        "muc_meeting_id";
        "muc_domain_mapper";
        "muc_rate_limit";
        "polls";
    }
    admins = { "focus@auth.{{SUBDOMAIN.DOMAIN.TLD}}" }
    muc_room_locking = false
    muc_room_default_public_jids = true

-- internal muc component
Component "internal.auth.{{SUBDOMAIN.DOMAIN.TLD}}" "muc"
    storage = "memory"
    modules_enabled = {
        "muc_hide_all";
        "ping";
    }
    admins = { "focus@auth.{{SUBDOMAIN.DOMAIN.TLD}}", "jvb@auth.{{SUBDOMAIN.DOMAIN.TLD}}" }
    muc_room_locking = false
    muc_room_default_public_jids = true

VirtualHost "auth.{{SUBDOMAIN.DOMAIN.TLD}}"
    ssl = {
        key = "/etc/prosody/certs/auth.{{SUBDOMAIN.DOMAIN.TLD}}.key";
        certificate = "/etc/prosody/certs/auth.{{SUBDOMAIN.DOMAIN.TLD}}.crt";
    }
    modules_enabled = {
        "limits_exception";
    }
    authentication = "internal_hashed"

-- Proxy to jicofo's user JID, so that it doesn't have to register as a component.
Component "focus.{{SUBDOMAIN.DOMAIN.TLD}}" "client_proxy"
    target_address = "focus@auth.{{SUBDOMAIN.DOMAIN.TLD}}"

Component "speakerstats.{{SUBDOMAIN.DOMAIN.TLD}}" "speakerstats_component"
    muc_component = "conference.{{SUBDOMAIN.DOMAIN.TLD}}"

Component "conferenceduration.{{SUBDOMAIN.DOMAIN.TLD}}" "conference_duration_component"
    muc_component = "conference.{{SUBDOMAIN.DOMAIN.TLD}}"

Component "endconference.{{SUBDOMAIN.DOMAIN.TLD}}" "end_conference"
    muc_component = "conference.{{SUBDOMAIN.DOMAIN.TLD}}"

Component "avmoderation.{{SUBDOMAIN.DOMAIN.TLD}}" "av_moderation_component"
    muc_component = "conference.{{SUBDOMAIN.DOMAIN.TLD}}"

Component "lobby.{{SUBDOMAIN.DOMAIN.TLD}}" "muc"
    storage = "memory"
    restrict_room_creation = true
    muc_room_locking = false
    muc_room_default_public_jids = true
    modules_enabled = {
        "muc_hide_all";
        "muc_rate_limit";
        "polls";
    }

Component "metadata.{{SUBDOMAIN.DOMAIN.TLD}}" "room_metadata_component"
    muc_component = "conference.{{SUBDOMAIN.DOMAIN.TLD}}"
    breakout_rooms_component = "breakout.{{SUBDOMAIN.DOMAIN.TLD}}"
