import subprocess
import os
import re
import requests
import sys
from git import Repo, GitCommandError
from pathlib import Path
from environs import Env

#=======================================================#
#================== Global parameters ==================#
#=======================================================#
env = Env()

#Default values
JENKINS_URL_DEFAULT ={"prod":"https://jenkins-prod.fr/generic-webhook-trigger/invoke","preprod":"https://jenkins-preprod.fr/generic-webhook-trigger/invoke"}
DOCKER_COMPOSE_TYPE_DEFAULT =["swarm"]  
PIPELINES_NAMES_LIST_DEFAULT=["Pipeline Name"]
PATH_GIT_DEFAULT='/usr/local/clusters/'
REGISTRY_PATHS_DEFAULT =["registry.gitlab.fr"]

# Global/Env variables
JENKINS_URL=env.json('PIPELINES_NAMES',JENKINS_URL_DEFAULT)
DOCKER_COMPOSE_TYPE=env.list('DOCKER_COMPOSE_TYPE',DOCKER_COMPOSE_TYPE_DEFAULT)
REGISTRY_PATHS=env.list('REGISTRY_PATHS',REGISTRY_PATHS_DEFAULT)
PIPELINES_NAMES_LIST=env.list('PIPELINES_NAMES_LIST',PIPELINES_NAMES_LIST_DEFAULT)
PIPELINES_NAMES = {}
for i in range(len(PIPELINES_NAMES_LIST)) :
    PIPELINES_NAMES[DOCKER_COMPOSE_TYPE[i]] = PIPELINES_NAMES_LIST[i]

PATH_GIT=os.environ.get('PATH_GIT',PATH_GIT_DEFAULT)
CI_JOB_TOKEN=os.environ.get('CI_JOB_TOKEN','')

#=======================================================#
#====================== Functions ======================#
#=======================================================#

def pull_cluster_repo(path) :
    # Walk through only immediate subdirectories (one level)
    cluster_repo_path = Path(path)
    for item in cluster_repo_path.iterdir():
        if item.is_dir():
            print(f" Processing {item}...")
            repo = Repo(item)
                # Get the remote URL
            if repo.remotes:
                remote = repo.remotes.origin
                old_url = remote.url

                # Parse HTTPS URL: https://[user:pass@]host/path
                # Group 1: protocol (https://)
                # Group 2: optional credentials with @ (user:pass@)
                # Group 3: host and path (github.com/user/repo.git)
                pattern = r'^(https?://)((?:[^@/]+)@)?(.+)$'
                match = re.match(pattern, old_url)
                
                if match:
                    protocol = match.group(1)
                    host_and_path = match.group(3)
                    new_url = f"{protocol}gitlab-ci-token:{CI_JOB_TOKEN}@{host_and_path}"
                    
                    remote.set_url(new_url)
                    try:
                        print(f"  → Pulling latest changes...")
                        repo.remotes.origin.pull()
                        print(f"  ✓ Pull completed")
                        return True
                    except GitCommandError as e:
                        print(f"  ❌ Pull failed: {str(e)}")
                        return False

                else :
                    print(f"Match failed for {item} git config")

def find_docker_compose_paths(path,registry) :
    tag = os.environ["TAG"]
    docker_compose_paths = []

    tag = f'{registry}/{tag.split("/",1)[-1]}'
    print(f'Tag : {tag}')

    #Launch a sh script that do a grep
    try :
        files_greped = subprocess.check_output(['sh',path + 'grep.sh',path,tag]).decode(sys.stdout.encoding)

    except subprocess.CalledProcessError as err:
        print("No cluster found...({0})".format(err))
        return(docker_compose_paths)
    else :
        for subdir, dirs, file_names in os.walk(path):
            for file_name in file_names:
                file_path = subdir + os.sep + file_name

                if file_path in files_greped:
                    print("{0} image is used in {1} docker compose.".format(tag,file_path))
                    docker_compose_paths.append(file_path)
    
    return docker_compose_paths

def determine_type_docker_paths(docker_compose_paths) :
    
    docker_compose_paths_typed = []

    for docker_compose_path in docker_compose_paths :
        is_typed = False
        for i in range(len(DOCKER_COMPOSE_TYPE)) :
            type_in_path_format = "/" + DOCKER_COMPOSE_TYPE[i] + "/"
            if type_in_path_format in docker_compose_path :
                docker_compose_paths_typed.append({'docker_compose_path':docker_compose_path,'docker_compose_type':DOCKER_COMPOSE_TYPE[i]})
                is_typed = True
                print("{0} docker compose is a {1} docker compose".format(docker_compose_path,DOCKER_COMPOSE_TYPE[i]))

        if not is_typed :
            docker_compose_paths_typed.append({'docker_compose_path':docker_compose_path,'docker_compose_type':None})
            print("{0} docker compose is not typed".format(docker_compose_path))
        
    
    return docker_compose_paths_typed


def get_clusters(path, docker_compose_paths_typed):
    clusters = []
    for docker_compose_path_typed in docker_compose_paths_typed :
        type = docker_compose_path_typed["docker_compose_type"]
        if type != None :
            #Find cluster name
            regex = re.match(path.replace("/", "\\/")+"([^\/\s]+)\/"+type, docker_compose_path_typed["docker_compose_path"])
            cluster_name = regex.group(1)
            print(cluster_name)
            if cluster_name != None :
                new_cluster = {"name":cluster_name,"pipeline_name":PIPELINES_NAMES[type]}
                
                is_duplicate = False
                if len(clusters) == 0 :
                    is_duplicate = False
                else:
                    for cluster in clusters :
                        is_already_present = True
                        for key in cluster.keys() :
                            if cluster[key] != new_cluster[key] :
                                is_already_present = False
                        if is_already_present :
                            is_duplicate = True
                
                print(is_duplicate)
                if not is_duplicate :
                    clusters.append(new_cluster)

    print("clusters :")
    print(clusters)

    return(clusters)

def get_image_info(registry):
    name = os.environ["NAME"]
    path = "cicd-docker/" + name + "/digest.txt"
    image_info = {}

    try:
        # Read digest artifact
        digest = open(path, 'r')
    except OSError as err:
        print("digest not found... ({0})".format(err))
    else :
        content = digest.read()
        print("digest : {1}".format("digest", content))

        image_name_with_registry = content.split("@")[0]
        if registry not in image_name_with_registry :
            image_name_with_registry = f'{registry}/{image_name_with_registry.split("/",1)[-1]}'
        image_name = image_name_with_registry.split("/")[-1]
        latest_docker_image_digest = content.split("@")[1]
        image_info = {"image_name_with_registry":image_name_with_registry,"image_name":image_name,"latest_docker_image_digest":latest_docker_image_digest}

        print("image_name_with_registry = " + str(image_name_with_registry) )
        print("image_name = " + str(image_name) )
        print("latest_docker_image_digest = " + str(latest_docker_image_digest))
    
    return image_info


def trigger_jenkins(cluster_by_registry) :
    jenkins_url = os.environ["JENKINS_URL"]
    jenkins_token = os.environ["JENKINS_TOKEN"]
    headers = {"token": jenkins_token}

    url = JENKINS_URL[jenkins_url]

    for element in cluster_by_registry :
        if len(element["clusters"]) != 0 :
            for cluster in element["clusters"] :
                additional_params = {"ref":element["image_info"]["image_name"],"stack":cluster["name"],"latest_docker_image_digest":element["image_info"]["latest_docker_image_digest"],"image_name":element["image_info"]["image_name_with_registry"]}
                data = {"pipeline_name":cluster["pipeline_name"],"additional_params":additional_params}
                response = requests.post(url=url,headers=headers,json=data)
                print(response.content)

#=======================================================#
#======================== Main =========================# 
#=======================================================#
                
def main():

    pull_cluster_repo(PATH_GIT)
    
    cluster_by_registry = []
    for registry in REGISTRY_PATHS :
        docker_compose_paths = find_docker_compose_paths(PATH_GIT,registry)
        docker_compose_paths_typed = determine_type_docker_paths(docker_compose_paths)
        clusters = get_clusters(PATH_GIT,docker_compose_paths_typed)
        image_info = get_image_info(registry)
        cluster_by_registry.append({'registry':registry, 'clusters': clusters, 'image_info': image_info})

    os.environ["http_proxy"]=""
    os.environ["HTTP_PROXY"]=""
    os.environ["https_proxy"]=""
    os.environ["HTTPS_PROXY"]=""

    if image_info != {} :
        trigger_jenkins(cluster_by_registry)

#=======================================================#
#====================== Main ===========================#
#=======================================================#


main()