{
  config,
  services,
  ...
}: {
  sops.secrets."nitter_sessions" = {};

  services.nitter = {
    enable = true;
    # jsonl, one {"kind":"cookie",...} session per line (tools/create_session_curl.py)
    sessionsFile = config.sops.secrets."nitter_sessions".path;
    # 6379 is livekit's; own instance on 6380
    redisCreateLocally = false;
    cache.redisPort = 6380;

    server = {
      address = "127.0.0.1";
      port = services.nitter.port;
      hostname = "nitter.marcel.cool";
      https = true;
      title = "nitter";
    };
  };

  services.redis.servers.nitter = {
    enable = true;
    port = 6380;
  };
}
