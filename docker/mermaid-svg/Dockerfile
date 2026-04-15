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

# Update font cache
RUN fc-cache -fv

# Set puppeteer to use system chromium instead of downloading its own
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Ensure puppeteer/chromium can write its config under any UID
ENV HOME=/tmp

# Install mermaid-cli globally
RUN npm install -g @mermaid-js/mermaid-cli

# Copy puppeteer config for sandboxed execution
COPY puppeteer-config.json /etc/puppeteer-config.json

# Set working directory
WORKDIR /workspace

# Default command
CMD ["mmdc", "--version"]
