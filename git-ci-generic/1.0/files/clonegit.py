#! /usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Entrypoint pour realiser des git clone depuis une Dockerfile multistage
#
# 29/08/2023 : Julien COMBES
#
# config.yaml par défaut :
#-----------------------------------------------------
# branchs_mapping:
#     prod: 'prod'
#     preprod: 'preprod'
# default_branch: 'preprod'
# fallback_to_default_branch: True
# clone_dir: '/source'
#-----------------------------------------------------


import sys
import os
import yaml
import git
import re
import argparse
import traceback

################################################################################
class CloneGit(object):
    ########################################
    def __init__(self, args) -> None:
        self.configfile = args.config
        self.gitrepo = args.gitrepo
        self.branch = args.branch
        self.debug = args.debug
        self.config = self.readconf()
        self.gitrepo_branch = self.calc_gitrepo_branch()
        self.git = git.cmd.Git()

    ########################################
    def log_debug(self, msg):
        if self.debug: print(msg)

    ########################################
    # Lit de fichier de configuration yaml
    # et/ou parametre les valeurs par defaut
    def readconf(self):
        try:
            default_values = {
                'branchs_mapping': {
                    'prod': 'prod',
                    'preprod': 'preprod'
                },
                'default_branch': 'preprod',
                'fallback_to_default_branch': True,
                'clone_dir': '/source'
            }

            if os.path.isfile(self.configfile):
                with open(self.configfile, 'r') as stream:
                    data_loaded = yaml.safe_load(stream)
                    if 'branchs_mapping' not in data_loaded:
                        data_loaded['branchs_mapping'] = default_values['branchs_mapping']
                    if 'prod' not in data_loaded['branchs_mapping']:
                        data_loaded['branchs_mapping']['prod'] = default_values['branchs_mapping']['prod']
                    if 'preprod' not in data_loaded['branchs_mapping']:
                        data_loaded['branchs_mapping']['preprod'] = default_values['branchs_mapping']['preprod']
                    if 'default_branch' not in data_loaded:
                        data_loaded['default_branch'] = default_values['default_branch']
                    if 'fallback_to_default_branch' not in data_loaded:
                        data_loaded['fallback_to_default_branch'] = default_values['fallback_to_default_branch']
                    if 'clone_dir' not in data_loaded:
                        data_loaded['clone_dir'] = default_values['clone_dir']
            else:
                data_loaded = default_values
            return data_loaded
        except:
            print('Erreur lors de la lecture de la configuration: {}'.format(traceback.format_exception(*sys.exc_info())))
            sys.exit(1)

    ########################################
    # Calcul la branche a chercher sur le git distant enfonction du mapping
    def calc_gitrepo_branch(self, branch=None):
        if branch is None: branch = self.branch
        if branch in self.config['branchs_mapping']:
            gitrepo_branch = self.config['branchs_mapping'][branch]
            self.log_debug("la branche {} est mappée sur {}.".format(branch, gitrepo_branch))
        else:
            gitrepo_branch = branch
            self.log_debug("la branche {} n'est pas mappée.".format(branch, gitrepo_branch))
        return gitrepo_branch

    ########################################
    # 
    # Si search_tag=False : cherche sur les branche
    # Si search_tag=True : cherche sur les tag
    def check_git_ref(self, branch_or_tag, search_tag=False):
        if not search_tag:
            # Cherche sur les branches
            git_opt = '--heads'
            type_ref = 'heads'
        else:
            # Cherche sur les tags
            git_opt = '--tags'
            type_ref = 'tags'

        ref_head = 'refs/{}/{}'.format(type_ref, branch_or_tag)
        refs = self.git.ls_remote(git_opt, self.gitrepo, ref_head).split()
        used_branch = None
        for ref in refs:
            if re.match(ref_head, ref):
                used_branch = branch_or_tag
                break
        return used_branch

    ########################################
    # Verifie si la branche de mapping existe sur le depot git et determine
    # la branche de travail en fonction des options de configurations
    # Si la branche n'existe pas : recherche d'un tag
    # Si le tag n'existe pas : bascule ou pas sur la branche par défaut
    # la configuration
    def get_branch(self):
        try:
            # recherche de la branche dans le depot git
            used_branch = self.check_git_ref(self.gitrepo_branch)
            if used_branch is None:
                self.log_debug("la branche {} n'existe pas".format(self.gitrepo_branch))
                # recherche de lu tag dans le depot git
                used_branch = self.check_git_ref(self.gitrepo_branch, search_tag=True)
                if used_branch is None:
                    self.log_debug("Le tag {} n'existe pas".format(self.gitrepo_branch))
                    if self.config['fallback_to_default_branch']:
                        git_fallback_branch = self.calc_gitrepo_branch(branch=self.config['default_branch'])
                        # recherche de la branche par defaut dans le depot git
                        used_branch = self.check_git_ref(git_fallback_branch)
                        if used_branch is None:
                            self.log_debug("La branche {} n'existe pas".format(git_fallback_branch))
                            # recherche du tag par defaut dans le depot git
                            used_branch = self.check_git_ref(git_fallback_branch, search_tag=True)
                            if used_branch is None:
                                print("Ni La branche (ou le tag) '{}', ni le branche (ou tag) par défaut '{}' n'existent pas dans le dépôt".format(
                                    self.gitrepo_branch,
                                    git_fallback_branch
                                ))
                                sys.exit(1)
                            else:
                                self.log_debug("Le tag {} existe".format(git_fallback_branch))
                        else:
                            self.log_debug("La branche {} existe".format(git_fallback_branch))
                    else:
                        print("La branche (ou le tag) '{}' n'existe pas dans le dépôt et fallback_to_default_branch=False".format(self.gitrepo_branch))
                        sys.exit(1)
                else:
                    self.log_debug("Le tag {} existe".format(self.gitrepo_branch))
            else:
                self.log_debug("La branche {} existe".format(self.gitrepo_branch))
            return used_branch
        except git.exc.GitCommandError as e:
            print("Erreur: {}".format(e.stderr))
            sys.exit(1)
        except:
            print("Erreur lors de la lecture de la branche: err {}".format(traceback.format_exception(*sys.exc_info())))
            sys.exit(1)

    ########################################
    def run(self):
        # Se postionner dans le dossier "clone_dir"
        try:
            if not os.path.isdir(self.config['clone_dir']):
                os.makedirs(self.config['clone_dir'])
        except Exception as e:
            print("Erreur avec {}: ".format(self.config['clone_dir'], traceback.format_exception(*sys.exc_info())))
        # os.chdir(self.config['clone_dir'])

        # Trouver la branche de travail avec la mapping
        used_branch = self.get_branch()

        # git clone
        try:
            dirpath = '{}/{}'.format(self.config['clone_dir'], self.gitrepo.split('.git')[0].split('/')[-1])
            self.log_debug("git clone sur la branche {} de {} dans {}".format(used_branch, self.gitrepo, dirpath))
            git.Repo.clone_from(url=self.gitrepo,single_branch=True, to_path=dirpath, branch=used_branch)
        except git.exc.GitCommandError as e:
            print("Erreur: {}".format(e.stderr))
            sys.exit(1)
        except:
            print("Erreur lors de la lecture de la branche: {}".format(traceback.format_exception(*sys.exc_info())))
            sys.exit(1)       



################################################################################
if __name__ == '__main__':
    parser = argparse.ArgumentParser (description='Entrypoint pour git clone')
    parser.add_argument('-c', '--config', help='Chemin du fichier de configuration', default='clonegit.yml')
    parser.add_argument('gitrepo')
    parser.add_argument('branch')
    parser.add_argument('-d', '--debug', help='Option de debug', action='store_true')
    args = parser.parse_args()

    cg = CloneGit(args)
    cg.run()
