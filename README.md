# gitc

A static git frontend written in ZSH.

## Configuration

- **Repository path** — set in `docker-compose.yml`. Defaults to the example repositories in `./repos`.
- **`src/style.css`** — stylesheet for the website.
- **`src/config`** — website configuration; set your subdirectory and site title here.

All configuration is live-updating — no rebuild required.

## Running

| Action  | Command                                  |
| ------- | ---------------------------------------- |
| Start   | `sudo docker compose up -d --build`      |
| Stop    | `sudo docker compose down`               |
| Restart | `sudo docker compose restart`            |

## Licence

Licensed under the [MIT Licence](/LICENCE) by MrurBo.
