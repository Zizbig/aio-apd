FROM python:3.12-slim

# ── Environment ──────────────────────────────────────────────
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    # Heroku injects $PORT; default locally to 8080
    PORT=8080 \
    TZ=Asia/Kolkata

ENV DEBIAN_FRONTEND=noninteractive

# ── System dependencies ───────────────────────────────────────
#  Includes deps for: backend (ffmpeg, unrar), autol (aria2, tini,
#  megatools, nodejs, busybox) and common tools (curl, wget, unzip).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        unzip \
        curl \
        wget \
        aria2 \
        tini \
        megatools \
        nodejs \
        busybox \
        procps \
    && rm -rf /var/lib/apt/lists/* \
    # unrar (full, not -free) via rar upstream tarball
    && wget -qO rarlinux.tar.gz https://www.rarlab.com/rar/rarlinux-x64-701.tar.gz \
    && tar -zxvf rarlinux.tar.gz \
    && mv rar/unrar /usr/bin/unrar \
    && rm -rf rar rarlinux.tar.gz

# ── Static binaries required by autol ────────────────────────
RUN \
    # Deno (used by yt-dlp for JS runtimes)
    curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh && \
    chmod +x /usr/local/bin/deno && \
    # N_m3u8DL-RE
    curl -sL "https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3u8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz" \
    | tar -xz -C /usr/local/bin N_m3u8DL-RE && \
    chmod +x /usr/local/bin/N_m3u8DL-RE && \
    # wgcf (Cloudflare WARP account generator)
    curl -sL "https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64" -o /usr/local/bin/wgcf && \
    chmod +x /usr/local/bin/wgcf && \
    # wireproxy (WireGuard SOCKS5 proxy)
    curl -sL "https://github.com/octeep/wireproxy/releases/download/v1.0.7/wireproxy_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin wireproxy && \
    chmod +x /usr/local/bin/wireproxy

# ── Working directory ─────────────────────────────────────────
WORKDIR /app

# ── Python dependencies ───────────────────────────────────────
#  Combined requirements for all three apps (backend, srcv6, autol).
COPY requirements.txt ./requirements.txt
RUN pip install --upgrade pip --root-user-action=ignore && \
    pip install -r requirements.txt --root-user-action=ignore

# ── yt-dlp (always fresh — autol needs latest) ────────────────
ARG YTDLP_VERSION
RUN pip install --no-cache-dir ${YTDLP_VERSION:+yt-dlp==${YTDLP_VERSION}} ${YTDLP_VERSION:-yt-dlp} \
    && yt-dlp --version

# ── Copy source ───────────────────────────────────────────────
#  Copies everything: srcv6/, backend/, autol/, start.sh, etc.
COPY . .

# ── Permissions ───────────────────────────────────────────────
RUN chmod +x start.sh

# ── Port ──────────────────────────────────────────────────────
EXPOSE 8080

# ── Entrypoint ────────────────────────────────────────────────
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "start.sh"]
