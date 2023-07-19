from io import BytesIO
import sys
import yaml
import json

with open('build.yml', "rb") as fh:
   buf = BytesIO(fh.read())
   dir = yaml.safe_load(buf)
   json.dump(dir, sys.stdout)
