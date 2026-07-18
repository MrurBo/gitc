# gitc

A static git frontend.

## Configuration

In `docker-compose.yml`, you can set your path to your repositories. defaults to example repositories in `./repos`
`src/style.css` Stylesheet for the website.
`src/config` Configuration for the website. In here you can set your subdirectory, and title for the website.

All configurations are live-updating.

## Running

`sudo docker compose up -d --build` to turn on,
`sudo docker compose down` to turn off,
`sudo docker compose restart` to restart.

## Licence

Licenced under [MIT Licence](/LICENCE) by MrurBo.
