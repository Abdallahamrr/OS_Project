FROM debian:stable-slim

WORKDIR /app

# 1. Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cron \
    procps \
    bc \
    findutils \
    tzdata \
    curl \
    python3 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. Set Timezone
ENV TZ=Africa/Cairo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 3. CREATE DIRECTORIES & COPY FILES (The missing part!)
RUN mkdir -p /app/collector /app/logs
COPY ./collector/ /app/collector/

# 4. Permissions & Windows-to-Linux Fix
# This ensures bash can read the files even if they were saved on Windows
RUN chmod +x /app/collector/*.sh && \
    sed -i 's/\r$//' /app/collector/*.sh


# 5. Run collector in an infinite loop every 10 seconds
CMD ["bash", "-c", "while true; do /app/collector/system_collector.sh; sleep 3; done"]