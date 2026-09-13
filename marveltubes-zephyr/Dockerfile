FROM docker.io/zephyrprojectrtos/zephyr-build@sha256:c4ba914436a19c3c7b2d454b8a67528559699aaf1bd2050fb4537b6797b86e8f

USER root

RUN /opt/python/venv/bin/python3 -m pip install --no-cache-dir \
        cbor2==6.1.4 \
        littlefs-python==0.19.0

USER user
