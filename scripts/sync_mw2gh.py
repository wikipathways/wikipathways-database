import base64
from datetime import date
from pathlib import Path

today = date.today()
# timestamp for yesterday
timestamp = "".join(
    [str(x) for x in [today.year, today.month, today.day - 1, "000000"]]
)
changes_url = (
    "https://webservice.wikipathways.org/getRecentChanges?timestamp="
    + timestamp
    + "&format=json"
)
changes_r = requests.get(changes_url)
changes_result = changes_r.json()

for pathway in changes_result["pathways"]:
    wpid = pathway["id"]
    curation_tags_url = (
        "https://webservice.wikipathways.org/getCurationTags?format=json&pwId="
        + wpid
    )
    curation_tags_r = requests.get(curation_tags_url)
    curation_tags_result = curation_tags_r.json()
    for tag in curation_tags_result["tags"]:
        if tag["name"] == "Curation:AnalysisCollection":
            gpml_url = (
                "https://webservice.wikipathways.org/getPathwayAs?format=json&fileType=gpml&pwId="
                + wpid
            )
            gpml_r = requests.get(gpml_url)
            gpml_result = gpml_r.json()
            gpml = base64.b64decode(gpml_result["data"])
            p = Path(wpid).with_suffix(".gpml")
            p.write_bytes(gpml)
