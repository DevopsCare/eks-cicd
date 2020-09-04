#
# Copyright (c) 2020 Risk Focus Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

#!/usr/bin/env python3
import os
import logging
from urllib.parse import urljoin
# from dataclasses import dataclass
from typing import Dict

import requests
from requests.auth import HTTPBasicAuth


# Setup logger
LOG_FORMAT = logging.Formatter(
    '%(asctime)s [%(threadName)s %(name)s] [%(levelname)s]  %(message)s')
console_handler = logging.StreamHandler()
console_handler.setFormatter(LOG_FORMAT)
logger = logging.getLogger(__name__)
logger.addHandler(console_handler)
logger.setLevel(level=logging.getLevelName('INFO'))


class NexusProvisionException(Exception):
    """
    Exception for GitStorage class
    """

    def __init__(self, *args):
        if args:
            self.message = args[0]
        else:
            self.message = None

    def __str__(self):
        if self.message:
            return f'NexusProvisionException: {self.message}'
        return f'NexusProvisionException has been raised'


class Config:
    _nexus_host: str = os.getenv(
        'NEXUS_URL', 'http://nexus')
    _nexus_api_path: str = os.getenv('NEXUS_API_PATH', 'service/rest/beta/')
    nexus_url: str = urljoin(_nexus_host, _nexus_api_path)

    nexus_username = os.getenv('NEXUS_ADMIN_USERNAME', 'admin')
    nexus_password = os.getenv('NEXUS_ADMIN_PASSWORD', 'admin123')
    nexus_auth = HTTPBasicAuth(nexus_username, nexus_password)

    _new_s3_blobstore_bucket_name = os.getenv(
        'S3_BUCKET_NAME', 'example-bucket')
    new_s3_blobstore_config = {
        'name': 'S3',
        'bucketConfiguration': {
            'bucket': {
                'region': 'DEFAULT',
                'name': _new_s3_blobstore_bucket_name,
                'prefix': '',
                'expiration': 3
            }
        }
    }

    _remote_repo_url = os.getenv('REMOTE_MAVEN_REPO_URL', 'http://example.com')
    remote_maven_repo = {'name': 'rf-snapshot',
                         'online': True,
                         'storage': {
                             'blobStoreName': 'S3',
                             'strictContentTypeValidation': True,
                             'writePolicy': 'ALLOW'
                         },
                         'cleanup': None,
                         'proxy': {
                             'remoteUrl': _remote_repo_url,
                             'contentMaxAge': 1,
                             'metadataMaxAge': 1
                         },
                         'negativeCache': {
                             'enabled': True,
                             'timeToLive': 1
                         },
                         'httpClient': {
                             'blocked': False,
                             'autoBlock': True,
                             'connection': None,
                             'authentication': {
                                 'type': 'username',
                                 'username': 'admin',
                                 'ntlmHost': None,
                                 'ntlmDomain': None}
                         },
                         'routingRuleName': None,
                         'maven': {
                             'versionPolicy': 'SNAPSHOT',
                             'layoutPolicy': 'STRICT'
                         },
                         'format': 'maven2',
                         'type': 'proxy'
                         }


def update_admin_password(config: Config) -> bool:
    response = requests.get(
        urljoin(config.nexus_url, 'security/users'), auth=config.nexus_auth)
    if response.ok:
        return False
    elif response.status_code in [401, 403]:
        # Try to use default
        response = requests.get(
            urljoin(config.nexus_url, 'security/users'), auth=HTTPBasicAuth('admin', 'admin123'))
        if response.status_code in [401, 403]:
            raise NexusProvisionException(
                'Provided credentials is not correct, default credentials: \
                admin:admin123 also doesn\'t work')
        elif response.ok:
            response = requests.put(
                urljoin(config.nexus_url,
                        'security/users/admin/change-password'),
                data=config.nexus_password,
                headers={'Content-type': 'text/plain'},
                auth=HTTPBasicAuth('admin', 'admin123'))
            if not response.ok:
                raise NexusProvisionException(
                    f'Cannot change password: {response.status_code}, {response.text}')
        else:
            raise NexusProvisionException(
                f'Wrong response from Nexus: {response.status_code}, {response.text}')
    else:
        raise NexusProvisionException(
            f'Wrong response from Nexus: {response.status_code}, {response.text}')
    return True


def get_resource(config: Config, api_type: str) -> Dict:
    response = requests.get(
        urljoin(config.nexus_url, api_type), auth=config.nexus_auth)
    if not response.ok:
        raise NexusProvisionException(
            f'Wrong response from Nexus: response code: {response.status_code}, {response.text}')
    try:
        data = response.json()
    except:
        raise NexusProvisionException(
            f'Can not deserialize from json {response.text}')
    return data


def create_s3_blobstore(config: Config, blobstore: Dict):
    response = requests.post(
        urljoin(config.nexus_url, f'blobstores/s3'), json=blobstore, auth=config.nexus_auth, timeout=60)
    if not response.ok:
        raise NexusProvisionException(
            f'Wrong response from Nexus: response code: {response.status_code}, {response.text}')
    else:
        logger.info('S3 blobstore created')


def update_repo(config: Config, repo_format: str, repo: dict):
    response = requests.put(
        urljoin(config.nexus_url,
                f'repositories/{repo_format}/{repo["type"]}/{repo["name"]}'),
        json=repo, auth=config.nexus_auth, timeout=120)
    if not response.ok:
        raise NexusProvisionException(
            f'Wrong response from Nexus: response code: {response.status_code}, {response.text}')
    else:
        logger.info(f'Repo {repo["name"]} has been updated')


def create_repo(config: Config, repo_format: str, repo: dict):
    response = requests.post(
        urljoin(config.nexus_url,
                f'repositories/{repo_format}/{repo["type"]}'),
        json=repo, auth=config.nexus_auth, timeout=120)
    if not response.ok:
        raise NexusProvisionException(
            f'Wrong response from Nexus: response code: {response.status_code}, {response.text}')
    else:
        logger.info(f'Repo {repo["name"]} has been created')


def delete_repo(config: Config, repo_name: str):
    response = requests.delete(
        urljoin(config.nexus_url,
                f'repositories/{repo_name}'),
        auth=config.nexus_auth, timeout=120)
    if not response.ok:
        raise NexusProvisionException(
            f'Wrong response from Nexus: response code: {response.status_code}, {response.text}')
    else:
        logger.info(f'Repo {repo_name} has been deleted')


def main():
    config = Config()

    if update_admin_password(config=config):
        logger.info('Password has been changed from default')

    blobstores = get_resource(config=config, api_type='blobstores')

    if config.new_s3_blobstore_config['name'] not in \
       [blobstore['name'] for blobstore in blobstores]:
        create_s3_blobstore(
            config=config, blobstore=config.new_s3_blobstore_config)

    rf_snapshots_maven_repo_existed = False

    repos = get_resource(config=config, api_type='repositories')
    for repo in repos:
        if repo['name'] == config.remote_maven_repo['name']:
            rf_snapshots_maven_repo_existed = True
            continue

        if repo['format'] == 'maven2':
            if repo['type'] in ['proxy', 'hosted', 'hosted'] and \
               repo['storage']['blobStoreName'] != 'S3':
                repo['storage']['blobStoreName'] = 'S3'
                update_repo(config=config, repo_format='maven', repo=repo)
        elif repo['format'] == 'nuget':
            delete_repo(config=config, repo_name=repo['name'])
        else:
            logger.info(
                f'repo must be updated manually - type {repo["format"]}, name {repo["name"]}')

    if not rf_snapshots_maven_repo_existed:
        create_repo(config=config, repo_format='maven',
                    repo=config.remote_maven_repo)
        logger.info(
            'Please setup http auth for rf-snapshot repo and add it to group members of group maven')


if __name__ == '__main__':
    main()
