"""Extract Zelda games → raw.zelda_games."""
from common import run

NAME = "games"
URL = "https://zelda.fanapis.com/api/games"

if __name__ == "__main__":
    run(NAME, URL)