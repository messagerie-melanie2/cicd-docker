import subprocess
import os
import re
import requests
import argparse

#=======================================================#
#================== Global parameters ==================#
#=======================================================#

JENKINS_URL_PROD = "https://jenkins-prod.mel.edcs.fr/jenkins-prod/generic-webhook-trigger/invoke"
JENKINS_URL_PREPROD = "https://jenkins-preprod.mel.edcs.fr/jenkins-preprod/generic-webhook-trigger/invoke"

#=======================================================#
#====================== Functions ======================#
#=======================================================#

def pull_cluster_repo() :
    subprocess.run(['sh','/usr/local/swarm_clusters/gitpull.sh'])

def find_stacks(debug) :
    tag = os.environ["TAG"]

    #Launch a sh script that do a grep
    try :
        files = subprocess.check_output(['sh','/usr/local/swarm_clusters/grep.sh',tag])

    except subprocess.CalledProcessError as err:
        print("No cluster found...({0})".format(err))
        return([])
    
    else :
        #Find cluster name
        stacks = re.findall("\/swarm_clusters\/([^\/\s]+)\/swarm", str(files), re.MULTILINE)

        #Get an array of only one occurence of a cluster
        if stacks != None :
            stacks_unique = []
            for stack in stacks :
                if stack not in stacks_unique :
                    stacks_unique.append(stack)

        if (debug) :
            print("tag = " + str(tag))
            print("stack_unique = ")
            print(stacks_unique)
        
        return(stacks_unique)

def trigger_jenkins(stacks_unique,debug) :
    jenkins_url = os.environ["JENKINS_URL"]
    jenkins_token = os.environ["JENKINS_TOKEN"]
    name = os.environ["NAME"]
    path = "cicd-docker/" + name + "/digest.txt"

    try:
        # Read digest artifact
        digest = open(path, 'r')

    except OSError as err:
        print("{0} not found... ({1})".format("digest", err))

    else :
        content = digest.read()
        if (debug) :
            print(content)

        image_name_with_registry = content.split("@")[0]
        image_name = image_name_with_registry.split("/")[-1]
        latest_docker_image_digest = content.split("@")[1]

        if (debug) :
            print("image_name_with_registry = " + str(image_name_with_registry) )
            print("image_name = " + str(image_name) )
            print("latest_docker_image_digest = " + str(latest_docker_image_digest))

        headers = {"token": jenkins_token}

        if jenkins_url == "prod":
            url = JENKINS_URL_PROD
        elif jenkins_url == "preprod":
            url = JENKINS_URL_PREPROD

        for stack in stacks_unique :
            additional_params = {"ref":image_name,"stack":stack,"latest_docker_image_digest":latest_docker_image_digest,"image_name":image_name_with_registry}
            data = {"pipeline_name":"Deploy mel_docker","additional_params":additional_params}
            response = requests.post(url=url,headers=headers,json=data)
            if (debug) :
                print(response.content)

#=======================================================#
#======================== Main =========================# 
#=======================================================#
                
def main(debug):

    pull_cluster_repo()
    
    stacks_unique = find_stacks(debug)

    os.environ["http_proxy"]=""
    os.environ["HTTP_PROXY"]=""
    os.environ["https_proxy"]=""
    os.environ["HTTPS_PROXY"]=""

    trigger_jenkins(stacks_unique,debug)

#=======================================================#
#====================== Arguments ======================#
#=======================================================#

# Create arguments parser
parser = argparse.ArgumentParser(
    prog='CICD Python Trigger Jenkins',
    description="Programme permettant de trigger une pipeline Jenkins en lui envoyant toute les informations nécéssaire")
parser.add_argument(
    '-d', '--debug-enabled', 
    default=False, action='store_true',
    help="Afficher plus de logs lors de l'exécution des fonctions")

# Run the arguments parser
args = parser.parse_args()

if(args.debug_enabled):
    print(args)

main(args.debug_enabled)