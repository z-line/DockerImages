# MarvelTubes Zephyr build image

This image extends the pinned official Zephyr build image with only the two
Python packages required by `zephyr/scripts/build_littlefs_images.py`.

```sh
docker build -t localhost/marveltubes-zephyr:4.4.0-1.0.1 .
```

The base image contains Zephyr SDK 1.0.1 and West 1.5.0. The project workspace
pins Zephyr 4.4.0 through its West manifest.
