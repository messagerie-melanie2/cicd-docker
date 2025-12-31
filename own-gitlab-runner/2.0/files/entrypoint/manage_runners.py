#! /usr/bin/env python3
# -*- coding: utf-8 -*-
####

import argparse
import requests
import subprocess
import os

#=======================================================#
#================== Global parameters ==================#
#=======================================================#

#Default values
GITLAB_URL_DEFAULT ='https://gitlab-forge.din.developpement-durable.gouv.fr/'
DESCRIPTION_DEFAULT ='docker-generated-runner'  
TAG_LIST_DEFAULT='docker,generated'
EXECUTOR_DEFAULT='docker'
DOCKER_IMAGE_DEFAULT='ruby:2.6'
DOCKER_HELPER_DEFAULT='gitlab/gitlab-runner-helper:x86_64-v17.11.3'
PROXY_PROTOCOL_DEFAULT='http://'
TEMPLATE_CONFIG_PATH_DEFAULT = "/etc/gitlab-runner/config.toml.template"

# Global/Env variables
TYPE=os.environ.get('TYPE')
INSTANCE_ID=os.environ.get('INSTANCE_ID')
DESCRIPTION=os.environ.get('DESCRIPTION',DESCRIPTION_DEFAULT)
TAG_LIST=os.environ.get('TAG_LIST',TAG_LIST_DEFAULT)
EXECUTOR=os.environ.get('EXECUTOR',EXECUTOR_DEFAULT)
DOCKER_IMAGE=os.environ.get('DOCKER_IMAGE',DOCKER_IMAGE_DEFAULT)
PROXY_URL=os.environ.get('PROXY_URL','')
NO_PROXY=os.environ.get('NO_PROXY','')
REGISTRY_MIRROR=os.environ.get('REGISTRY_MIRROR','')
GITLAB_URL=os.environ.get('GITLAB_URL',GITLAB_URL_DEFAULT)
DOCKER_HELPER=os.environ.get('DOCKER_HELPER',DOCKER_HELPER_DEFAULT)
PROXY_PROTOCOL=os.environ.get('PROXY_PROTOCOL',PROXY_PROTOCOL_DEFAULT)
TEMPLATE_CONFIG_PATH=os.environ.get('TEMPLATE_CONFIG_PATH',TEMPLATE_CONFIG_PATH_DEFAULT)

STATUS_RUNNER_TO_DELETE=["offline","never_contacted"]
RUNNERS_TYPE_INFO={'groups':{'type_name': 'group_type', 'id_name':'group_id'},'projects':{'type_name': 'project_type', 'id_name':'project_id'}}

GITLAB_TOKEN = '%%GITLAB_TOKEN%%'

#Proxy management 
PROXY_USERNAME='%%PROXY_USERNAME%%'
PROXY_PASSWORD='%%PROXY_PASSWORD%%'
PROXY_USER = ''
if PROXY_USERNAME != '' :
    PROXY_USER = PROXY_USERNAME + ':' + PROXY_PASSWORD + '@'
PROXY_URL = PROXY_PROTOCOL + PROXY_USER + PROXY_URL
PROXY_ARGS = ["--env","proxy_url=" + PROXY_URL,"--env", "http_proxy=" + PROXY_URL, "--env","https_proxy=" + PROXY_URL, "--env","HTTP_PROXY=" + PROXY_URL, "--env","HTTPS_PROXY=" + PROXY_URL]
PROXY_ARGS += ["--env","NO_PROXY=" + NO_PROXY, "--env","REGISTRY_MIRROR=" + REGISTRY_MIRROR]
#=======================================================#
#============== Gitlab Tools Functions =================#
#=======================================================#

def get_runners_info(debug = False):

    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    runners = []
    i = 0

    loop = True
    #Max per page is only 100 so we have to loop to get all repositories
    while loop and len(runners) == 100*i:
        url = GITLAB_URL + 'api/v4/' + TYPE + '/'+str(INSTANCE_ID)+'/runners?per_page=100&page='+str(i+1)
        
        try :
            r = requests.get(url, headers=headers)
            r.raise_for_status()
        
        except requests.exceptions.HTTPError as err:
            if debug : 
                print("Http Error:",err)
            loop = False
        
        else :
            runners += r.json()
            i += 1
    
    if debug :
        print(runners)
    
    return(runners)

def delete_runner(runner, debug = False):
    
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    url = GITLAB_URL + 'api/v4/runners/'+str(runner["id"])
    deleted = False
    
    try :
        r = requests.delete(url, headers=headers)
        r.raise_for_status()
    
    except requests.exceptions.HTTPError as err:
        if debug : 
            print("Http Error:",err)
        
    else :
        deleted = True
    
    return deleted

def create_runner(debug = False):
    
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    url = url = GITLAB_URL + 'api/v4/user/runners'
    new_runner = {}

    data = {
            'runner_type': RUNNERS_TYPE_INFO[TYPE]['type_name'],
            'description': DESCRIPTION,
            'tag_list': TAG_LIST,
        }
    
    data[RUNNERS_TYPE_INFO[TYPE]['id_name']] = INSTANCE_ID
    
    try :
        r = requests.post(url, headers=headers, data=data)
        r.raise_for_status()
    
    except requests.exceptions.HTTPError as err:
        if debug : 
            print("Http Error:",err)
        
    else :
        new_runner = r.json()
    
    return new_runner

#=======================================================#
#=================== Main functions ====================#
#=======================================================#

def get_runners_to_delete(runners) :

    runners_to_delete = []

    for runner in runners :
        if runner["status"] in STATUS_RUNNER_TO_DELETE :
            runners_to_delete.append(runner)
        if runner["description"] == DESCRIPTION :
            runners_to_delete.append(runner)
    
    return runners_to_delete

def setup_runner(runner_info) :
    print('[gitlab-runner-container] Registering a new runner :')
    cmd = ["gitlab-runner", "register","--non-interactive","--url",GITLAB_URL,"--token", runner_info["token"], "--executor", EXECUTOR, "--docker-image", DOCKER_IMAGE, "--docker-helper-image", DOCKER_HELPER, "--template-config", TEMPLATE_CONFIG_PATH]
    cmd += PROXY_ARGS
    subprocess.run(cmd)
    print("[gitlab-runner-container] Done !\r")
#=======================================================#
#======================== Main =========================#
#=======================================================#
        

def main(args) :
    runners = get_runners_info(args.debug_enabled)

    runners_to_delete = get_runners_to_delete(runners)

    for runner in runners_to_delete :
        if delete_runner(runner,args.debug_enabled) :
            print("Runner {0} (id:{1}) is deleted with success".format(runner["description"],runner["id"]))
    
    new_runner = create_runner(args.debug_enabled)

    setup_runner(new_runner)


#=======================================================#
#====================== Arguments ======================#
#=======================================================#

# Create arguments parser and mutually exclusive group
parser = argparse.ArgumentParser(
    prog='CICD Python Helper',
    description="Entrypoint des runners gitlab")
parser.add_argument(
    '-d', '--debug-enabled', 
    metavar='DEBUG', default=False,
    help="Afficher plus de logs lors de l'éxécution des fonctions")

# Run the arguments parser
args = parser.parse_args()

if args.debug_enabled == 'false' :
    args.debug_enabled = False
elif args.debug_enabled == 'true' :
    args.debug_enabled = True

if(args.debug_enabled):
    print(args)

main(args)

# End
print("\r")