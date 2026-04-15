# Mermaid to SVG Conversion Environment

FROM node:20-slim

# Install system packages
# - chromium: Required by mermaid-cli (puppeteer)
# - fonts-noto-cjk: Japanese fonts
# - fonts-ipafont: IPA fonts for Japanese
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    fonts-noto-cjk \
    fonts-ipafont \
    fonts-liberation \
    fontconfig \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Ensure puppeteer/chromium and fontconfig can write/read under any UID at runtime.
# Set HOME=/tmp BEFORE fc-cache so the user-cache lands somewhere readable at runtime.
# Compose also sets HOME=/tmp via environment; the ENV here is the fallback for
# `docker run`/`docker build` and any non-compose invocation.
ENV HOME=/tmp

# Update font cache
RUN fc-cache -fv

# Set puppeteer to use system chromium instead of downloading its own
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Install mermaid-cli globally
# Pin to 10.9.1: mermaid-cli 11.x uses mermaid v11 flowchart-v2 renderer where
# `flowchart.htmlLabels:false` no longer suppresses <foreignObject> output.
# We need <text>/<tspan> output so that wrap_textbox.embed_svg_native (lxml) can
# inject the SVG into Word DrawingML; <foreignObject>+HTML span renders blank.
RUN npm install -g @mermaid-js/mermaid-cli@10.9.1

# Copy puppeteer config for sandboxed execution
COPY puppeteer-config.json /etc/puppeteer-config.json

# Copy mermaid configFile (forces htmlLabels=false → SVG <text> instead of <foreignObject>)
COPY mermaid-config.json /etc/mermaid-config.json

# Set working directory
WORKDIR /workspace

# Default command
CMD ["mmdc", "--version"]
