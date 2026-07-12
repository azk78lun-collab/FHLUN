const ASSETS = {
  "xray-amd64": "https://github.com/azk78lun-collab/FHLUN/releases/download/lun/xray-amd64",
  "xray-arm64": "https://github.com/azk78lun-collab/FHLUN/releases/download/lun/xray-arm64",
  "sing-box-amd64": "https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-amd64",
  "sing-box-arm64": "https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-arm64",
  "cloudflared-linux-amd64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64",
  "cloudflared-linux-arm64": "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64",
};

const PREFIX = "/fhlun/";
const CACHE_SECONDS = 86_400;

export default {
  async fetch(request, _env, ctx) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const url = new URL(request.url);
    if (!url.pathname.startsWith(PREFIX)) {
      return new Response("FHLUN core mirror", { status: 404 });
    }

    const asset = url.pathname.slice(PREFIX.length);
    const upstream = ASSETS[asset];
    if (!upstream || asset.includes("/")) {
      return new Response("Asset Not Found", { status: 404 });
    }

    const cache = caches.default;
    const cacheKey = new Request(`${url.origin}${PREFIX}${asset}`);
    let response = await cache.match(cacheKey);

    if (!response) {
      const upstreamResponse = await fetch(upstream, {
        cf: { cacheEverything: true, cacheTtl: CACHE_SECONDS },
        headers: { "User-Agent": "FHLUN-Core-Mirror" },
      });

      if (!upstreamResponse.ok) {
        return new Response("Upstream download failed", { status: 502 });
      }

      const headers = new Headers(upstreamResponse.headers);
      headers.set("Cache-Control", `public, max-age=${CACHE_SECONDS}`);
      headers.set("Content-Disposition", `attachment; filename=\"${asset}\"`);
      response = new Response(upstreamResponse.body, {
        status: upstreamResponse.status,
        headers,
      });
      ctx.waitUntil(cache.put(cacheKey, response.clone()));
    }

    return request.method === "HEAD"
      ? new Response(null, { status: response.status, headers: response.headers })
      : response;
  },
};
