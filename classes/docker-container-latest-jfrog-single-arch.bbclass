include docker-container.bbclass

FILTER_NUMERIC_TAGS ?= "False"
USE_ARTIFACTORY_AUTH ?= "True"

python get_latest_version_info() {
    import requests
    from requests.auth import HTTPBasicAuth
    import json
    from dateutil.parser import parse
    from datetime import datetime
    import pytz

    tz_lon = pytz.timezone("Europe/London")
    newest_tag = None
    newest_date = tz_lon.localize(datetime(1900, 1, 1, 0, 0, 0))

    requests_session = requests.Session()

    basicAuth = None

    if d.getVar('ARTIFACTORY_DOCKER_REGISTRY_USER') and d.getVar('ARTIFACTORY_DOCKER_REGISTRY_PASSWORD'):
        basicAuth = HTTPBasicAuth(d.getVar('ARTIFACTORY_DOCKER_REGISTRY_USER'), d.getVar('ARTIFACTORY_DOCKER_REGISTRY_PASSWORD'))
    else:
        bb.warn("No Authentication for Docker API Set");


    # Get all Tags of the Image
    tagListUrl = d.getVar('API') + "/" + d.getVar('UNAME') + "/" + d.getVar('IMAGE') + "/tags/list"
    tagListResult = requests_session.get(tagListUrl, auth=basicAuth)

    if tagListResult.status_code != 200 or tagListResult.status_code != 200:
        bb.fatal("API Error: Could not get list of tags. " + str(tagListResult.status_code) + " " + tagListUrl)


    if d.getVar('FILTER_NUMERIC_TAGS') == "True":
        # Filter non numeric Tags
        filtered_tags = [e for e in tagListResult.json()['tags'] if e.isnumeric()]
    else:
        filtered_tags = tagListResult.json()['tags']


    for tag in filtered_tags:
        # Get creation Time of Image
        manifestV1Url = d.getVar('API') + "/" + d.getVar('UNAME') + "/" + d.getVar('IMAGE') + "/manifests/" + tag
        manifestV1Result = requests_session.get(manifestV1Url, auth=basicAuth)


        if manifestV1Result.status_code != 200 or manifestV1Result.status_code != 200:
            bb.fatal("API Error: Could not get list of tags. " + str(manifestV1Result.status_code) + " " + manifestV1Url) 

        # Search for newest Tag
        date = parse(json.loads(manifestV1Result.json()['history'][0]['v1Compatibility'])['created'])
        bb.note(str(date) + " - " + tag)
        if(date > newest_date):
            newest_date = date
            newest_tag = tag


    # Get SHA256 Hahs of newest Image
    manifestV2Url = d.getVar('API') + "/" + d.getVar('UNAME') + "/" + d.getVar('IMAGE') + "/manifests/" + newest_tag
    manifestV2Result = requests_session.get(manifestV2Url, auth=basicAuth, headers={"Accept": "application/vnd.docker.distribution.manifest.v2+json"})

    if manifestV2Result.status_code != 200 or manifestV2Result.status_code != 200:
        bb.fatal("API Error: Could not get list of tags. " + str(manifestV2Result.status_code) + " " + manifestV2Url)

    d.setVar('SHAHASH', manifestV2Result.headers['Docker-Content-Digest'])
}


do_pull_image[prefuncs] += "get_latest_version_info"
do_tag_image[prefuncs] += "get_latest_version_info"
do_save_image[prefuncs] += "get_latest_version_info"
do_install[prefuncs] += "get_latest_version_info"