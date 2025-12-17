#! /usr/bin/env python3

import subprocess
import requests
import os

#=======================================================#
#================== Global parameters ==================#
#=======================================================#

GITLAB_URL = os.environ.get('GITLAB_PROTOCOL',"https://") + os.environ.get('GITLAB_DOMAIN',"")

#=======================================================#
#====================== Functions ======================#
#=======================================================#

def get_groups_info(token, group_id = 0):

    headers = {"PRIVATE-TOKEN": token}
    projects = []

    i = 0
    error = False

    #Max per page is only 100 so we have to loop to get all projects
    while len(projects) == 100*i  and not error:

        url = GITLAB_URL + 'api/v4/groups/'+str(group_id)+'/projects?per_page=100&page='+str(i+1)
        try :
            r = requests.get(url, headers=headers)
            r.raise_for_status()
    
        except requests.exceptions.HTTPError as err:
            print("Http Error:",err)
            raise
        
        else :
            projects += r.json()
            i += 1
    
    return(projects)

def git_clone_project(project_url):
    try:
        command = ["git","clone",project_url]
        subprocess.run(command, check=True)
        print("SUCCESS executing command:", " ".join(command))
    except subprocess.CalledProcessError as e:
        error_msg = f"FAILED cloning '{project_url}': {e}"
        print(error_msg)
        raise

def git_clone_all_project(token, projects):

    group_info = []

    for project in projects :
        project_url = project["http_url_to_repo"]
        project_url_split = project_url.split("://")
        project_url_with_token=project_url_split[0] + "://" + "gitlab-ci-token:" + str(token) + "@" + project_url_split[-1]

        git_clone_project(project_url_with_token)
    
    return(group_info)

#=======================================================#
#======================== Main =========================# 
#=======================================================#
                
def main():

    group_id = os.environ.get("GROUP_ID")
    token_api = os.environ.get("CICD_GMCD_TOKEN")
    token_clone = os.environ.get("CI_JOB_TOKEN")

    projects = get_groups_info(token_api,group_id)

    git_clone_all_project(token_clone, projects)

main()