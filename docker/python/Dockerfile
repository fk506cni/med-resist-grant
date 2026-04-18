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
    librsvg2-bin \
    && rm -rf /var/lib/apt/lists/*

# Update font cache
RUN fc-cache -fv

# Install Pandoc from GitHub release
RUN wget -q "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-amd64.deb" \
    -O /tmp/pandoc.deb \
    && dpkg -i /tmp/pandoc.deb \
    && rm /tmp/pandoc.deb

# Install Python packages
# Note: ruamel.yaml.clib (C extension) is not installed because python:3.12-slim
# lacks a C compiler. Pure Python fallback is used instead, which is sufficient
# for the small YAML files in this project (performance impact: negligible).
RUN pip install --no-cache-dir \
    python-docx \
    openpyxl \
    pyyaml \
    ruamel.yaml \
    Jinja2 \
    pypdf

WORKDIR /workspace

CMD ["python", "--version"]
