# Use official n8n image as base
FROM docker.n8n.io/n8nio/n8n:latest

USER root

# Install ffmpeg, python3, pip and other tools
RUN apt-get update && \
    apt-get install -y ffmpeg python3 python3-pip wget curl jq && \
    pip3 install gTTS && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create a scripts dir and copy our media script
RUN mkdir -p /home/node/scripts && chown node:node /home/node/scripts
COPY generate_media_and_upload.sh /home/node/scripts/generate_media_and_upload.sh
RUN chmod +x /home/node/scripts/generate_media_and_upload.sh && chown node:node /home/node/scripts/generate_media_and_upload.sh

# Return to node user (n8n runs as node)
USER node

# Keep default CMD from n8n image (no override) so n8n starts normally
