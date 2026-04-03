# med-resist-grant: Python + Pandoc Build Environment
FROM python:3.12-slim

ARG PANDOC_VERSION=3.6.4

ENV DEBIAN_FRONTEND=noninteractive

# Install system packages + Japanese fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    fonts-noto-cjk \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Update font cache
RUN fc-cache -fv

# Install Pandoc from GitHub release
RUN wget -q "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-amd64.deb" \
    -O /tmp/pandoc.deb \
    && dpkg -i /tmp/pandoc.deb \
    && rm /tmp/pandoc.deb

# Install Python packages
RUN pip install --no-cache-dir \
    python-docx \
    openpyxl \
    pyyaml \
    ruamel.yaml \
    Jinja2

WORKDIR /workspace

CMD ["python", "--version"]
