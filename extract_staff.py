"""Extract Zelda staff → raw.zelda_staff."""

from common import run

NAME = "staff"
URL = "https://zelda.fanapis.com/api/staff"

if __name__ == "__main__":
    run(NAME, URL)