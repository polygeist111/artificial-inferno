## BASE IMAGE

**Build Image:**
```
docker build -t tarpit_apis-dev-env-image .
```

**Start Container:**
```
docker run --name tarpit-apis-dev-env --env-file .env -d -v "$(pwd)/src:/app" -p 127.0.0.1:5000:5000 tarpit-apis-dev-env-image
```

**Remove Container:**
```
docker rm tarpit-apis-dev-env
```

**Troubleshooting:**  
If anything hangs, remember to docker login


## HOT RELOADABLE

**Build Image:**
```
docker build -t tarpit-apis-hot-reload .
```

**Start Container:**
```
docker run --name tarpit-apis-hot-reload --env-file .env -d -v "$(pwd)/src:/app" -p 127.0.0.1:5000:5000 tarpit-apis-hot-reload
```

**Remove Container:**
```
docker rm tarpit-apis-hot-reload
```

**Full Cycle**
```
docker rm tarpit-apis-hot-reload 2>/dev/null &&
docker build -t tarpit-apis-hot-reload . &&
docker run --name tarpit-apis-hot-reload --env-file .env -d -v "$(pwd)/src:/app" -p 127.0.0.1:5000:5000 tarpit-apis-hot-reload
```

## GENERAL

**See Logs:**
```
docker logs <container-name> | Select-Object -First 10
```

**Use Terminal (no attach):**
```
docker exec -it <container-name> /bin/bash
```

## NOTES

Manager scripts were written for a discord bot, not a Flask API, hence the variable names. This can be disregarded