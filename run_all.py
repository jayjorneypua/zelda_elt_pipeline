"""Run every extractor in sequence."""
from common import run

EXTRACTORS = [
    ("games", "https://zelda.fanapis.com/api/games"),
    ("staff", "https://zelda.fanapis.com/api/staff"),
    ("characters", "https://zelda.fanapis.com/api/characters"),
    ("monsters", "https://zelda.fanapis.com/api/monsters"),
    ("bosses", "https://zelda.fanapis.com/api/bosses"),
    ("dungeons", "https://zelda.fanapis.com/api/dungeons"),
    ("places", "https://zelda.fanapis.com/api/places"),
    ("items", "https://zelda.fanapis.com/api/items"),
]

if __name__ == "__main__":
    for name, url in EXTRACTORS:
        run(name, url)